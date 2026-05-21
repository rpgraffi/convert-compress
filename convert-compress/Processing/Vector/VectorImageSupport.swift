import Foundation
import AppKit
import CoreImage
import UniformTypeIdentifiers

enum VectorImageSupport {
    private static let minLongEdge: CGFloat = 1024
    private static let maxLongEdge: CGFloat = 3840
    private static let upscaleFactor: CGFloat = 4

    static let loaders: [VectorImageLoader.Type] = [
        SVGImageLoader.self,
    ]

    // MARK: - Public API

    static func isVectorImage(_ url: URL) -> Bool {
        loader(for: url) != nil
    }

    static var allSupportedUTTypes: [UTType] {
        loaders.flatMap { $0.supportedUTTypes }
    }

    static func intrinsicSize(for url: URL) throws -> CGSize {
        guard let loader = loader(for: url) else { throw VectorImageError.unsupportedFormat }
        return try loader.intrinsicSize(for: url)
    }

    /// Computes a generous rasterization size for upscaling support:
    /// intrinsic x4, clamped to [1024, 3840] on the long edge.
    static func generousSize(for intrinsic: CGSize) -> CGSize {
        let scaled = CGSize(width: intrinsic.width * upscaleFactor, height: intrinsic.height * upscaleFactor)
        let longEdge = max(scaled.width, scaled.height)

        if longEdge < minLongEdge {
            let factor = minLongEdge / max(max(intrinsic.width, intrinsic.height), 1)
            return CGSize(width: (intrinsic.width * factor).rounded(), height: (intrinsic.height * factor).rounded())
        }

        if longEdge > maxLongEdge {
            let factor = maxLongEdge / longEdge
            return CGSize(width: (scaled.width * factor).rounded(), height: (scaled.height * factor).rounded())
        }

        return CGSize(width: scaled.width.rounded(), height: scaled.height.rounded())
    }

    /// Loads a vector image and returns a CIImage rasterized at `targetSize` pixels.
    static func loadAsCIImage(from url: URL, targetSize: CGSize) throws -> CIImage {
        let nsImage = try loadNSImage(from: url)
        AppLogger.processing.debug("Loading vector as CIImage: \(url.lastPathComponent, privacy: .public) at \(Int(targetSize.width))×\(Int(targetSize.height))")
        return CIImage(cgImage: try rasterize(nsImage: nsImage, at: targetSize))
    }

    /// Loads a vector image as a thumbnail at the given max pixel size.
    /// Returns the rasterized thumbnail and the image's intrinsic pixel dimensions.
    static func loadThumbnail(for url: URL, maxPixelSize: Int) throws -> (thumbnail: NSImage, pixelSize: CGSize) {
        let nsImage = try loadNSImage(from: url)
        let intrinsic = try intrinsicSize(for: url)

        let scale = min(1.0, CGFloat(maxPixelSize) / max(intrinsic.width, intrinsic.height))
        let thumbSize = CGSize(
            width: (intrinsic.width * scale).rounded(),
            height: (intrinsic.height * scale).rounded()
        )

        let cgImage = try rasterize(nsImage: nsImage, at: thumbSize)
        let displayScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let pointSize = NSSize(width: CGFloat(cgImage.width) / displayScale, height: CGFloat(cgImage.height) / displayScale)
        return (NSImage(cgImage: cgImage, size: pointSize), intrinsic)
    }

    // MARK: - Private Helpers

    private static func loader(for url: URL) -> VectorImageLoader.Type? {
        loaders.first { $0.canHandle(url) }
    }

    private static func loadNSImage(from url: URL) throws -> NSImage {
        guard let nsImage = NSImage(contentsOf: url) else {
            AppLogger.processing.error("NSImage failed to load: \(url.lastPathComponent, privacy: .public)")
            throw VectorImageError.rasterizationFailed
        }
        return nsImage
    }

    private static func rasterize(nsImage: NSImage, at size: CGSize) throws -> CGImage {
        let w = Int(size.width)
        let h = Int(size.height)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw VectorImageError.rasterizationFailed
        }

        rep.size = NSSize(width: w, height: h)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        nsImage.draw(
            in: NSRect(x: 0, y: 0, width: w, height: h),
            from: NSRect(origin: .zero, size: nsImage.size),
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = rep.cgImage else {
            throw VectorImageError.rasterizationFailed
        }
        return cgImage
    }
}
