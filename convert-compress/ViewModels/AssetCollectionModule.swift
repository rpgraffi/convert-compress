import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AssetCollectionModule {
    var images: [ImageAsset] = [] {
        didSet {
            onImagesChanged?()
        }
    }
    var sourceDirectory: URL?
    var ingestionProgress = ProgressState()

    @ObservationIgnored var onImagesChanged: (() -> Void)?
    @ObservationIgnored private var ingestionTasks: [UUID: Task<Void, Never>] = [:]

    var ingestFraction: Double {
        ingestionProgress.fraction
    }

    var ingestCounterText: String? {
        ingestionProgress.ingestCounterText
    }

    var hasExportedAndNewImages: Bool {
        let hasExported = images.contains { $0.isEdited }
        let hasNew = images.contains { !$0.isEdited }
        return hasExported && hasNew
    }

    func addURLs(_ urls: [URL]) {
        let taskID = UUID()
        ingestionTasks[taskID] = Task(priority: .medium) { [weak self] in
            await self?.runIngestionTask(id: taskID, urls: urls)
        }
    }

    func addProvidersStreaming(_ providers: [NSItemProvider], batchSize: Int = 64) {
        let taskID = UUID()
        ingestionTasks[taskID] = Task(priority: .medium) { [weak self] in
            await self?.runProviderIngestionTask(id: taskID, providers: providers, batchSize: batchSize)
        }
    }

    func addFromPasteboard() {
        let urls = IngestionCoordinator.collectURLsFromPasteboard()
        addURLs(urls)
    }

    @discardableResult
    func remove(_ asset: ImageAsset) -> Bool {
        guard let index = images.firstIndex(of: asset) else {
            return false
        }

        _ = withAnimation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0.2)) {
            images.remove(at: index)
        }
        return true
    }

    func replaceImages(_ updatedImages: [ImageAsset]) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.3)) {
            images = updatedImages
        }
    }

    func clearAll(clearSourceDirectory: Bool = true) {
        cancelIngestion()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3)) {
            images.removeAll()
        }

        if clearSourceDirectory {
            sourceDirectory = nil
        }
    }

    @discardableResult
    func clearExported() -> Set<UUID> {
        let exportedIDs = Set(images.filter(\.isEdited).map(\.id))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3)) {
            images.removeAll { $0.isEdited }
        }
        return exportedIDs
    }

    func cancelIngestion() {
        for task in ingestionTasks.values {
            task.cancel()
        }
        ingestionTasks.removeAll()
        ingestionProgress.reset()
    }

    func firstSourceSizeForRestrictions() -> CGSize? {
        images.first?.originalPixelSize
    }

    func basePixelSizeForCurrentSelection() -> CGSize? {
        let sizes: [CGSize] = images.compactMap { asset in
            guard let size = asset.originalPixelSize else { return nil }
            return VectorImageSupport.isVectorImage(asset.originalURL) ? VectorImageSupport.generousSize(for: size) : size
        }
        guard !sizes.isEmpty else { return nil }
        let maxWidth = sizes.map(\.width).max() ?? 0
        let maxHeight = sizes.map(\.height).max() ?? 0
        return CGSize(width: maxWidth, height: maxHeight)
    }

    private func runIngestionTask(id: UUID, urls: [URL]) async {
        defer {
            ingestionTasks[id] = nil
        }

        await ingest(urls: urls)
    }

    private func runProviderIngestionTask(id: UUID, providers: [NSItemProvider], batchSize: Int) async {
        defer {
            ingestionTasks[id] = nil
        }

        let stream = IngestionCoordinator.streamURLs(from: providers, batchSize: batchSize)
        for await urls in stream {
            guard !Task.isCancelled else { return }
            await ingest(urls: urls)
        }
    }

    private func ingest(urls: [URL]) async {
        guard !Task.isCancelled else { return }

        let existingURLs = Set(images.map(\.originalURL))
        guard let prepared = IngestionPlanner().prepare(urls: urls, existingURLs: existingURLs) else {
            return
        }

        if let sourceDirectory = prepared.sourceDirectory {
            self.sourceDirectory = sourceDirectory
        }
        ingestionProgress.addToTotal(prepared.assets.count)
        images.append(contentsOf: prepared.assets)

        AppLogger.ingestion.debug("Appended assets. Total images: \(self.images.count, privacy: .public)")

        await loadThumbnails(for: prepared.assets)

        guard !Task.isCancelled else { return }
        AppLogger.ingestion.debug("Ingest complete for batch of \(prepared.assets.count, privacy: .public) URLs")
    }

    private func loadThumbnails(for assets: [ImageAsset]) async {
        let semaphore = AsyncSemaphore(value: 16)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        await withTaskGroup(of: Void.self) { group in
            for asset in assets {
                guard !Task.isCancelled else { break }

                group.addTask(priority: .medium) { [weak self] in
                    await self?.loadThumbnail(for: asset, scale: scale, semaphore: semaphore)
                }
            }
        }
    }

    private func loadThumbnail(for asset: ImageAsset, scale: CGFloat, semaphore: AsyncSemaphore) async {
        await semaphore.acquire()
        defer { Task { await semaphore.release() } }

        guard !Task.isCancelled else { return }

        let fileName = asset.originalURL.lastPathComponent
        AppLogger.ingestion.debug("Thumbnail load begin: \(fileName, privacy: .public)")

        let output = await ImageAssetMetadataLoader.load(for: asset.originalURL, scale: scale)
        guard !Task.isCancelled else { return }

        AppLogger.ingestion.debug("""
            Thumbnail load done: \(fileName, privacy: .public) \
            thumb? \(output.thumbnail != nil) \
            size? \(output.pixelSize != nil) \
            bytes? \(output.fileSizeBytes != nil)
            """)

        applyThumbnailUpdate(for: asset, output: output)
        incrementIngestionProgress()
    }

    private func applyThumbnailUpdate(for asset: ImageAsset, output: ImageAssetMetadataLoader.Output) {
        guard let index = images.firstIndex(where: { $0.id == asset.id }) else {
            AppLogger.ingestion.warning("""
                Thumbnail update skipped; asset missing: \
                \(asset.originalURL.lastPathComponent, privacy: .public)
                """)
            return
        }

        images[index].thumbnail = output.thumbnail
        images[index].originalPixelSize = output.pixelSize
        images[index].originalFileSizeBytes = output.fileSizeBytes
        images[index].originalFormat = output.originalFormat

        AppLogger.ingestion.debug("Thumbnail applied: \(asset.originalURL.lastPathComponent, privacy: .public)")
    }

    private func incrementIngestionProgress() {
        ingestionProgress.increment()
    }
}

