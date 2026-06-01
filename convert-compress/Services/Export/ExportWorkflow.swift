import Foundation

struct ExportWorkflow {
    let destinationResolver: ExportDestinationResolver
    let configuration: ProcessingConfiguration
    let targets: [ImageAsset]
    let initialImages: [ImageAsset]
    let encodedOutputCache: EncodedOutputCache
    let maxConcurrent: Int
    let dependencies: ExportWorkflowDependencies

    func run() async -> ExportResult {
        guard !targets.isEmpty else {
            return .succeeded(updatedImages: initialImages, totalCount: 0)
        }

        if Task.isCancelled {
            return .cancelled(
                updatedImages: initialImages,
                failures: [],
                completedCount: 0,
                totalCount: targets.count
            )
        }

        let conflicts = destinationConflicts()
        if !conflicts.isEmpty {
            let shouldReplace = await dependencies.confirmReplace(conflicts)
            guard shouldReplace else {
                return .replaceCancelled(initialImages: initialImages, totalCount: targets.count)
            }
        }

        let writeScopeDirectories = uniqueWriteScopeDirectories()
        var writeScopeTokens: [SandboxAccessToken] = []
        defer {
            for token in writeScopeTokens {
                token.stop()
            }
        }

        for directory in writeScopeDirectories {
            if Task.isCancelled {
                return .cancelled(
                    updatedImages: initialImages,
                    failures: [],
                    completedCount: 0,
                    totalCount: targets.count
                )
            }

            let message = String(localized: "Allow \(AppConstants.localizedAppName) to save files in \(directory.lastPathComponent)?")
            let granted = await dependencies.requestAccess(directory, message)
            if !granted {
                await dependencies.presentAccessDenied(directory)
                return .accessDenied(directory: directory, initialImages: initialImages, totalCount: targets.count)
            }

            guard let token = dependencies.beginAccess(directory) else {
                await dependencies.presentAccessDenied(directory)
                return .accessDenied(directory: directory, initialImages: initialImages, totalCount: targets.count)
            }
            writeScopeTokens.append(token)
        }

        await dependencies.beginProgress(targets.count)
        let writeAccess = ExportWriteAccess(scopeDirectories: writeScopeDirectories)

        let runner = ExportRunner(
            destinationResolver: destinationResolver,
            configuration: configuration,
            encodedOutputCache: encodedOutputCache,
            maxConcurrent: maxConcurrent,
            writeAccess: writeAccess
        )
        let runResult = await runner.run(
            targets: targets,
            initialImages: initialImages
        ) {
            dependencies.incrementProgress()
        }

        if runResult.wasCancelled || Task.isCancelled {
            return .cancelled(
                updatedImages: runResult.updatedImages,
                failures: runResult.failures,
                completedCount: runResult.completedCount,
                totalCount: targets.count
            )
        }

        guard runResult.failures.isEmpty else {
            return .completedWithFailures(
                updatedImages: runResult.updatedImages,
                failures: runResult.failures,
                completedCount: runResult.completedCount,
                totalCount: targets.count
            )
        }

        return .succeeded(updatedImages: runResult.updatedImages, totalCount: targets.count)
    }

    @MainActor
    func performPostExportSideEffects(for result: ExportResult) {
        guard result.shouldRunPostExportSideEffects else { return }

        dependencies.recordUsage(result.exportedCount)
        dependencies.checkRatingPrompt()

        let urlsToReveal = result.editedURLs
        if !urlsToReveal.isEmpty {
            dependencies.revealInFinder(urlsToReveal)
        }
    }

    private func destinationConflicts() -> [URL] {
        let planned = plannedDestinationURLs()
        let uniquePlanned = Array(Set(planned))
        let fileManager = FileManager.default
        return uniquePlanned.filter { fileManager.fileExists(atPath: $0.path) }
    }

    private func uniqueWriteScopeDirectories() -> [URL] {
        let destinations = plannedDestinationURLs()
            .map { $0.deletingLastPathComponent().standardizedFileURL }
        var seen: Set<URL> = []
        var result: [URL] = []
        for directory in destinations {
            let scopeDirectory = nearestExistingDirectory(for: directory)
            if !seen.contains(scopeDirectory) {
                seen.insert(scopeDirectory)
                result.append(scopeDirectory)
            }
        }
        return result
    }

    private func nearestExistingDirectory(for directory: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.standardizedFileURL
        var isDirectory: ObjCBool = false

        while !fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            let parent = candidate.deletingLastPathComponent().standardizedFileURL
            guard parent.path != candidate.path else {
                return directory.standardizedFileURL
            }
            candidate = parent
            isDirectory = false
        }

        return candidate
    }

    private func plannedDestinationURLs() -> [URL] {
        targets.enumerated().map { index, asset in
            destinationResolver.destinationURL(
                for: .planned(
                    asset: asset,
                    index: index,
                    totalCount: targets.count,
                    configuration: configuration
                )
            )
        }
    }
}
