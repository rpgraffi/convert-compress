import AppKit
import ImageIO

struct ImageAssetMetadataLoader {
    struct Output: Sendable {
        let thumbnail: NSImage?
        let pixelSize: CGSize?
        let fileSizeBytes: Int?
        let originalFormat: ImageFormat?
    }

    static func load(for url: URL, scale: CGFloat, maxPixelSize: CGFloat = 256) async -> Output {
        AppLogger.ingestion.debug("Loading thumbnail: \(url.lastPathComponent, privacy: .public)")

        let standardizedURL = url.standardizedFileURL
        let pixelMax = max(1, Int(maxPixelSize * scale))

        let fileSizeBytes = try? standardizedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        let originalFormat = ImageIOCapabilities.shared.formatForURL(standardizedURL)

        if VectorImageSupport.isVectorImage(standardizedURL) {
            return loadVectorImage(
                url: standardizedURL,
                maxPixelSize: pixelMax,
                fileSizeBytes: fileSizeBytes,
                originalFormat: originalFormat
            )
        }

        var pixelSize: CGSize?
        var thumbnail: NSImage?

        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(standardizedURL as CFURL, sourceOptions as CFDictionary) else {
            return Output(
                thumbnail: nil,
                pixelSize: nil,
                fileSizeBytes: fileSizeBytes,
                originalFormat: originalFormat
            )
        }

        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let w = props[kCGImagePropertyPixelWidth] as? NSNumber,
           let h = props[kCGImagePropertyPixelHeight] as? NSNumber {
            pixelSize = CGSize(width: CGFloat(truncating: w), height: CGFloat(truncating: h))
        }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelMax,
            kCGImageSourceShouldCacheImmediately: true
        ]

        if let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) {
            let size = NSSize(width: CGFloat(cgThumb.width) / scale, height: CGFloat(cgThumb.height) / scale)
            thumbnail = NSImage(cgImage: cgThumb, size: size)
        }

        return Output(
            thumbnail: thumbnail,
            pixelSize: pixelSize,
            fileSizeBytes: fileSizeBytes,
            originalFormat: originalFormat
        )
    }

    private static func loadVectorImage(
        url: URL,
        maxPixelSize: Int,
        fileSizeBytes: Int?,
        originalFormat: ImageFormat?
    ) -> Output {
        guard let token = SandboxAccessToken(url: url) else {
            return Output(
                thumbnail: nil,
                pixelSize: nil,
                fileSizeBytes: fileSizeBytes,
                originalFormat: originalFormat
            )
        }
        defer { token.stop() }

        guard let (thumb, intrinsic) = try? VectorImageSupport.loadThumbnail(for: url, maxPixelSize: maxPixelSize) else {
            return Output(
                thumbnail: nil,
                pixelSize: nil,
                fileSizeBytes: fileSizeBytes,
                originalFormat: originalFormat
            )
        }

        return Output(
            thumbnail: thumb,
            pixelSize: intrinsic,
            fileSizeBytes: fileSizeBytes,
            originalFormat: originalFormat
        )
    }
}
