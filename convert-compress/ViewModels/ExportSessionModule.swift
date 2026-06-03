import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ExportSessionModule {
    private typealias Keys = StorageKeys.Pipeline

    var exportDirectory: URL? = nil {
        didSet {
            if let exportDirectory {
                UserDefaults.standard.set(exportDirectory.path, forKey: Keys.exportDirectory)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.exportDirectory)
            }
        }
    }
    var exportProgress = ProgressState()

    @ObservationIgnored private let settings: PipelineSettingsModule
    @ObservationIgnored private let assets: AssetCollectionModule
    @ObservationIgnored private let rename: ExportRenameModule
    @ObservationIgnored private let encodedOutputCache: EncodedOutputCache
    @ObservationIgnored private let alertView: ExportAlertView
    @ObservationIgnored private var exportTask: Task<Void, Never>?

    init(
        settings: PipelineSettingsModule,
        assets: AssetCollectionModule,
        rename: ExportRenameModule,
        encodedOutputCache: EncodedOutputCache,
        alertView: ExportAlertView = ExportAlertView()
    ) {
        self.settings = settings
        self.assets = assets
        self.rename = rename
        self.encodedOutputCache = encodedOutputCache
        self.alertView = alertView
        self.rename.configureDestinationResolver { [weak self] in
            self?.exportDestinationResolver()
                ?? ExportDestinationResolver(
                    exportDirectory: nil,
                    folderStructureRoot: nil,
                    renameSettings: .disabled
                )
        }
        loadPersistedState()
    }

    var isExportingToSource: Bool {
        guard let source = assets.sourceDirectory?.standardizedFileURL else {
            return false
        }
        guard let export = exportDirectory?.standardizedFileURL else {
            return true
        }
        return export == source
    }

    var isExporting: Bool {
        exportProgress.isActive
    }

    var exportCompleted: Int {
        exportProgress.completed
    }

    var exportTotal: Int {
        exportProgress.total
    }

    var exportFraction: Double {
        exportProgress.fraction
    }

    func applyPipelineAsync() {
        PaywallCoordinator.shared.requestAccess { [weak self] in
            self?.executeExport()
        }
    }

    func cancelExport() {
        exportTask?.cancel()
        exportProgress.reset()
    }

    private func loadPersistedState() {
        if let exportPath = UserDefaults.standard.string(forKey: Keys.exportDirectory) {
            exportDirectory = URL(fileURLWithPath: exportPath)
        }
    }

    private func recommendedConcurrency() -> Int {
        ExportConcurrencyPolicy.recommended()
    }

    private func executeExport() {
        guard exportTask == nil else { return }

        if let selectedFormat = settings.selectedFormat {
            settings.bumpRecentFormats(selectedFormat)
        }
        let configuration = settings.currentConfiguration
        let targets = assets.images
        guard !targets.isEmpty else { return }
        let initialImages = assets.images
        let maxConcurrent = recommendedConcurrency()
        let destinationResolver = exportDestinationResolver()
        let dependencies = exportWorkflowDependencies()
        let encodedOutputCache = encodedOutputCache

        exportTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let workflow = ExportWorkflow(
                destinationResolver: destinationResolver,
                configuration: configuration,
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

    private func beginExport(total: Int) {
        exportProgress.begin(total: total)
    }

    private func incrementExportProgress() {
        exportProgress.increment()
    }

    private func finishExport(with result: ExportResult) {
        if result.status == .cancelled, assets.images.isEmpty {
            exportProgress.reset()
            return
        }

        assets.replaceImages(result.updatedImages)
        exportProgress.reset()
    }

    private func exportDestinationResolver() -> ExportDestinationResolver {
        let keepStructure = UserDefaults.standard.bool(forKey: StorageKeys.Preferences.keepFolderStructure)
        return ExportDestinationResolver(
            exportDirectory: exportDirectory,
            folderStructureRoot: keepStructure ? assets.sourceDirectory : nil,
            renameSettings: rename.exportSettings
        )
    }

    private func exportWorkflowDependencies() -> ExportWorkflowDependencies {
        ExportWorkflowDependencies(
            confirmReplace: { [weak self] conflictingURLs in
                self?.alertView.confirmReplace(conflictingURLs: conflictingURLs) ?? false
            },
            requestAccess: { directory, message in
                await SandboxAccessManager.shared.requestAccessIfNeeded(to: directory, message: message)
            },
            beginAccess: { directory in
                SandboxAccessManager.shared.beginAccess(for: directory)
            },
            presentAccessDenied: { [weak self] directory in
                self?.alertView.presentAccessDenied(for: directory)
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
}
