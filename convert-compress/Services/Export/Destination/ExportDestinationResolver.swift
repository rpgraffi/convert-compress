import Foundation

struct ExportDestinationResolver {
    let exportDirectory: URL?
    let folderStructureRoot: URL?
    let renameSettings: ExportRenameSettings
    let today: Date

    init(
        exportDirectory: URL?,
        folderStructureRoot: URL?,
        renameSettings: ExportRenameSettings = .disabled,
        today: Date = Date()
    ) {
        self.exportDirectory = exportDirectory
        self.folderStructureRoot = folderStructureRoot
        self.renameSettings = renameSettings
        self.today = today
    }

    func destinationURL(for request: ExportDestinationRequest) -> URL {
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: request.outputUTType)
        let base = basename(for: request, filenameExtension: ext)
        return destinationDirectory(for: request.asset)
            .appendingPathComponent(base + "." + ext)
    }

    private func destinationDirectory(for asset: ImageAsset) -> URL {
        let currentURL = asset.originalURL

        if let exportDirectory {
            return targetDirectory(for: currentURL, in: exportDirectory)
        }

        if isTemporarySource(currentURL) {
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
        }

        return currentURL.deletingLastPathComponent()
    }

    private func targetDirectory(for sourceURL: URL, in exportDirectory: URL) -> URL {
        guard let folderStructureRoot else { return exportDirectory }

        let assetDirectory = sourceURL.deletingLastPathComponent().standardizedFileURL
        let sourcePath = folderStructureRoot.standardizedFileURL.path
        let assetPath = assetDirectory.path
        let relativePath = assetPath.hasPrefix(sourcePath)
            ? String(assetPath.dropFirst(sourcePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            : ""

        return relativePath.isEmpty
            ? exportDirectory
            : exportDirectory.appendingPathComponent(relativePath)
    }

    private func basename(for request: ExportDestinationRequest, filenameExtension: String) -> String {
        let dates = fileDates(for: request.asset.originalURL)
        let context = ExportFilenameContext(
            asset: request.asset,
            index: request.index,
            totalCount: request.totalCount,
            configuration: request.configuration,
            outputUTType: request.outputUTType,
            outputSize: TargetSize.size(for: request.asset, configuration: request.configuration),
            today: today,
            created: dates.created,
            modified: dates.modified
        )
        return ExportFilenameBuilder(settings: renameSettings)
            .basename(for: context, filenameExtension: filenameExtension)
    }

    private func fileDates(for url: URL) -> (created: Date?, modified: Date?) {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return (values?.creationDate, values?.contentModificationDate)
    }

    private func isTemporarySource(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(FileManager.default.temporaryDirectory.standardizedFileURL.path)
    }
}
