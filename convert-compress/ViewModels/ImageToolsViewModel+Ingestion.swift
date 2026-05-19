import Foundation
import AppKit
import SwiftUI

extension ImageToolsViewModel {
    func addURLs(_ urls: [URL]) {
        Task(priority: .medium) { [weak self] in
            await self?.ingest(urls: urls)
        }
    }

    func addProvidersStreaming(_ providers: [NSItemProvider], batchSize: Int = 64) {
        Task(priority: .medium) { [weak self] in
            guard let self else { return }
            let stream = IngestionCoordinator.streamURLs(from: providers, batchSize: batchSize)
            for await urls in stream {
                await self.ingest(urls: urls)
            }
        }
    }

    func addFromPasteboard() {
        let urls = IngestionCoordinator.collectURLsFromPasteboard()
        addURLs(urls)
    }

    func remove(_ asset: ImageAsset) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0.2)) {
            if let idx = images.firstIndex(of: asset) { images.remove(at: idx) }
        }
        processedCache.removeValue(forKey: asset.id)
    }

    func bumpRecentFormats(_ format: ImageFormat) {
        var recents = RecentList(recentFormats, maxCount: 3)
        recents.insert(format)
        recentFormats = recents.elements
    }
    
    // MARK: - Private Methods

    private func ingest(urls: [URL]) async {
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
        AppLogger.ingestion.debug("Ingest complete for batch of \(prepared.assets.count, privacy: .public) URLs")
    }
    
    private func loadThumbnails(for assets: [ImageAsset]) async {
        let semaphore = AsyncSemaphore(value: 16)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        await withTaskGroup(of: Void.self) { group in
            for asset in assets {
                group.addTask(priority: .medium) { [weak self] in
                    await self?.loadThumbnail(for: asset, scale: scale, semaphore: semaphore)
                }
            }
        }
    }
    
    private func loadThumbnail(for asset: ImageAsset, scale: CGFloat, semaphore: AsyncSemaphore) async {
        await semaphore.acquire()
        defer { Task { await semaphore.release() } }
        
        let fileName = asset.originalURL.lastPathComponent
        AppLogger.ingestion.debug("Thumbnail load begin: \(fileName, privacy: .public)")
        
        let output = await ThumbnailGenerator.load(for: asset.originalURL, scale: scale)
        
        AppLogger.ingestion.debug("""
            Thumbnail load done: \(fileName, privacy: .public) \
            thumb? \(output.thumbnail != nil) \
            size? \(output.pixelSize != nil) \
            bytes? \(output.fileSizeBytes != nil)
            """)
        
        applyThumbnailUpdate(for: asset, output: output)
        incrementIngestionProgress()
    }

    private func applyThumbnailUpdate(for asset: ImageAsset, output: ThumbnailGenerator.Output) {
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
        
        AppLogger.ingestion.debug("Thumbnail applied: \(asset.originalURL.lastPathComponent, privacy: .public)")
    }

    private func incrementIngestionProgress() {
        ingestionProgress.increment()
    }
}
