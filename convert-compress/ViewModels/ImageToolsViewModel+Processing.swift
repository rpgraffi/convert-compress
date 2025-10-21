import Foundation
import SwiftUI
import AppKit

extension ImageToolsViewModel {
    func buildPipeline() -> ProcessingPipeline {
        let pipeline = PipelineBuilder().build(
            resizeMode: resizeMode,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
            resizeLongSide: resizeLongSide,
            selectedFormat: selectedFormat,
            compressionPercent: compressionPercent,
            flipV: flipV,
            removeBackground: removeBackground,
            removeMetadata: removeMetadata,
            exportDirectory: exportDirectory
        )
        if let fmt = selectedFormat { bumpRecentFormats(fmt) }
        return pipeline
    }


    // Async concurrent export
    func recommendedConcurrency() -> Int {
        let info = ProcessInfo.processInfo
        var concurrency = min(16, max(4, info.activeProcessorCount * 2))
        // Adjust for physical memory bands (rough heuristic)
        let gb = Double(info.physicalMemory) / (1024.0 * 1024.0 * 1024.0)
        if gb < 4.0 { concurrency = min(concurrency, 4) }
        else if gb < 8.0 { concurrency = min(concurrency, 8) }
        if info.isLowPowerModeEnabled { concurrency = max(4, min(concurrency, 8)) }
        switch info.thermalState {
        case .fair:
            concurrency = min(concurrency, 8)
        case .serious, .critical:
            concurrency = min(concurrency, 4)
        default:
            break
        }
        return max(2, min(concurrency, 16))
    }

    func applyPipelineAsync() {
        PaywallCoordinator.shared.requestAccess { [weak self] in
            self?.executeExport()
        }
    }
    
    private func executeExport() {
        let pipeline = buildPipeline()
        let targets = images
        guard !targets.isEmpty else { return }

        // Preflight replace confirmation (single dialog for all files)
        if !preflightReplaceIfNecessary(pipeline: pipeline, targets: targets) {
            return
        }

        let directories = uniqueDestinationDirectories(for: targets, pipeline: pipeline)

        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            for directory in directories {
                let message = String(localized: "Allow Convert & Compress to save files in \(directory.lastPathComponent)?")
                let granted = await SandboxAccessManager.shared.requestAccessIfNeeded(to: directory, message: message)
                if !granted {
                    self.presentAccessDeniedAlert(for: directory)
                    return
                }
            }

            self.beginExport(total: targets.count)

            let hint = self.recommendedConcurrency()
            var updatedImages = self.imagesSnapshot()

            await withTaskGroup(of: (ImageAsset, ImageAsset)?.self) { group in
                var iterator = targets.makeIterator()
                let boost = max(1, Int(Double(hint) * 1.5))
                let limit = min(boost, targets.count)

                func addNextTask(from iterator: inout IndexingIterator<[ImageAsset]>, to group: inout TaskGroup<(ImageAsset, ImageAsset)?>) {
                    guard let asset = iterator.next() else { return }
                    group.addTask(priority: .utility) {
                        do {
                            let updated = try pipeline.run(on: asset)
                            return (asset, updated)
                        } catch {
                            return nil
                        }
                    }
                }

                for _ in 0..<limit {
                    addNextTask(from: &iterator, to: &group)
                }

                while let result = await group.next() {
                    if let (original, updated) = result,
                       let idx = updatedImages.firstIndex(of: original) {
                        updatedImages[idx] = updated
                    }

                    self.incrementExportProgress()

                    addNextTask(from: &iterator, to: &group)
                    await Task.yield()
                }
            }

            self.finishExport(with: updatedImages)
        }
    }
}

extension ImageToolsViewModel {
    private func beginExport(total: Int) {
        exportTotal = total
        exportCompleted = 0
        isExporting = true
    }

    private func incrementExportProgress() {
        exportCompleted += 1
    }

    private func finishExport(with imagesToCommit: [ImageAsset]) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.3)) {
            images = imagesToCommit
        }
        isExporting = false
        exportCompleted = 0
        exportTotal = 0
        UsageTracker.shared.recordPipelineApplied()

        let urlsToReveal = imagesToCommit.compactMap { $0.isEdited ? $0.workingURL : nil }
        if !urlsToReveal.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(urlsToReveal)
        }
    }

    private func imagesSnapshot() -> [ImageAsset] {
        images
    }

    /// Returns true if export should proceed, false if user cancelled.
    private func preflightReplaceIfNecessary(pipeline: ProcessingPipeline, targets: [ImageAsset]) -> Bool {
        guard !targets.isEmpty else { return true }
        let planned: [URL] = targets.map { pipeline.plannedDestinationURL(for: $0) }
        // Only unique destinations matter for conflict check
        let uniquePlanned = Array(Set(planned))
        let fm = FileManager.default
        let conflicts = uniquePlanned.filter { fm.fileExists(atPath: $0.path) }
        guard !conflicts.isEmpty else { return true }

        // Prefer showing the parent folder if all in same directory
        let parentDirs = Set(conflicts.map { $0.deletingLastPathComponent().path })
        let folderHintPath = parentDirs.count == 1 ? parentDirs.first! : nil
        let message = String(localized: "Replace existing files?")
        let count = conflicts.count
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

    func uniqueDestinationDirectories(for targets: [ImageAsset], pipeline: ProcessingPipeline) -> [URL] {
        let destinations = targets.map { pipeline.plannedDestinationURL(for: $0).deletingLastPathComponent().standardizedFileURL }
        var seen: Set<URL> = []
        var result: [URL] = []
        for directory in destinations {
            if !seen.contains(directory) {
                seen.insert(directory)
                result.append(directory)
            }
        }
        return result
    }

    @MainActor
    func presentAccessDeniedAlert(for directory: URL) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = String(localized: "Permission needed")
        alert.informativeText = String(localized: "Convert & Compress needs access to save files in \(directory.lastPathComponent). Please choose Allow when prompted.")
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }
}


