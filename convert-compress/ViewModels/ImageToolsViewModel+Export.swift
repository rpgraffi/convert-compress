import Foundation
import SwiftUI
import AppKit

extension ImageToolsViewModel {
    /// Recommended concurrency for export, balancing CPU / memory / thermal state.
    func recommendedConcurrency() -> Int {
        ExportConcurrencyPolicy.recommended()
    }

    func applyPipelineAsync() {
        PaywallCoordinator.shared.requestAccess { [weak self] in
            self?.executeExport()
        }
    }

    func cancelExport() {
        exportTask?.cancel()
    }

    private func executeExport() {
        guard exportTask == nil else { return }

        if let selectedFormat { bumpRecentFormats(selectedFormat) }
        let config = currentConfiguration
        let targets = images
        guard !targets.isEmpty else { return }
        let initialImages = imagesSnapshot()
        let maxConcurrent = recommendedConcurrency()
        let destinationResolver = exportDestinationResolver()
        let dependencies = exportWorkflowDependencies()
        let encodedOutputCache = encodedOutputCache

        exportTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let workflow = ExportWorkflow(
                destinationResolver: destinationResolver,
                configuration: config,
                targets: targets,
                initialImages: initialImages,
                encodedOutputCache: encodedOutputCache,
                maxConcurrent: maxConcurrent,
                dependencies: dependencies
            )

            let result = await workflow.run()
            self.finishExport(with: result)
            workflow.performPostExportSideEffects(for: result)
            self.exportTask = nil
        }
    }

    // MARK: - Progress

    private func beginExport(total: Int) {
        exportProgress.begin(total: total)
    }

    private func incrementExportProgress() {
        exportProgress.increment()
    }

    private func finishExport(with result: ExportResult) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.3)) {
            images = result.updatedImages
        }
        exportProgress.reset()
    }

    private func imagesSnapshot() -> [ImageAsset] {
        images
    }

    // MARK: - Dependencies

    private func exportDestinationResolver() -> ExportDestinationResolver {
        let keepStructure = UserDefaults.standard.bool(forKey: StorageKeys.Preferences.keepFolderStructure)
        return ExportDestinationResolver(
            exportDirectory: exportDirectory,
            folderStructureRoot: keepStructure ? sourceDirectory : nil
        )
    }

    private func exportWorkflowDependencies() -> ExportWorkflowDependencies {
        ExportWorkflowDependencies(
            confirmReplace: { [weak self] conflictingURLs in
                self?.confirmReplace(conflictingURLs: conflictingURLs) ?? false
            },
            requestAccess: { directory, message in
                await SandboxAccessManager.shared.requestAccessIfNeeded(to: directory, message: message)
            },
            beginAccess: { directory in
                SandboxAccessManager.shared.beginAccess(for: directory)
            },
            presentAccessDenied: { [weak self] directory in
                self?.presentAccessDeniedAlert(for: directory)
            },
            beginProgress: { [weak self] total in
                self?.beginExport(total: total)
            },
            incrementProgress: { [weak self] in
                self?.incrementExportProgress()
            },
            recordUsage: { imageCount in
                UsageTracker.shared.recordPipelineApplied(imageCount: imageCount)
            },
            checkRatingPrompt: {
                RatingCoordinator.shared.checkAndShowIfNeeded()
            },
            revealInFinder: { urls in
                if UserDefaults.standard.object(forKey: StorageKeys.Preferences.revealExportInFinder) as? Bool ?? true {
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }
            }
        )
    }

    // MARK: - Alerts

    /// Returns true if export should proceed, false if user cancelled.
    private func confirmReplace(conflictingURLs: [URL]) -> Bool {
        let parentDirs = Set(conflictingURLs.map { $0.deletingLastPathComponent().path })
        let folderHintPath = parentDirs.count == 1 ? parentDirs.first! : nil
        let message = String(localized: "Replace existing files?")
        let count = conflictingURLs.count
        var info = ""
        if let folderPath = folderHintPath {
            let folderName = FileManager.default.displayName(atPath: folderPath)
            if count == 1 {
                info = String(format: String(localized: "1 file already exists in \"%@\". Replacing will overwrite it."), folderName)
            } else {
                info = String(format: String(localized: "%d files already exist in \"%@\". Replacing will overwrite them."), count, folderName)
            }
        } else {
            if count == 1 {
                info = String(localized: "1 file with the same name already exists. Replacing will overwrite it.")
            } else {
                info = String(format: String(localized: "%d files with the same name already exist. Replacing will overwrite them."), count)
            }
        }

        func presentAlert() -> Bool {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = message
            alert.informativeText = info

            let replaceButton = alert.addButton(withTitle: String(localized: "Replace"))
            replaceButton.hasDestructiveAction = true

            alert.addButton(withTitle: String(localized: "Cancel"))
            if let icon = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) {
                alert.icon = icon
            }
            let resp = alert.runModal()
            return resp == .alertFirstButtonReturn
        }

        return presentAlert()
    }

    @MainActor
    func presentAccessDeniedAlert(for directory: URL) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = String(localized: "Permission needed")
        alert.informativeText = String(localized: "\(AppConstants.localizedAppName) needs access to save files in \(directory.lastPathComponent). Please choose Allow when prompted.")
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }
}
