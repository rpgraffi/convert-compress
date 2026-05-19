import Foundation
import AppKit
import UniformTypeIdentifiers
import libavif

struct AVIFEncoder: CustomImageEncoder {
    var supportsMetadataStripping: Bool { false }

    func canEncode(utType: UTType) -> Bool {
        utType == .avif
    }

    func encode(cgImage: CGImage, pixelSize: CGSize, utType: UTType, compressionQuality: Double?, stripMetadata: Bool) throws -> Data {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw ImageOperationError.exportFailed
        }

        let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: height * bytesPerRow)
        defer { pixels.deallocate() }

        guard let ctx = CGContext(
            data: pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageOperationError.exportFailed
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let avifImage = avifImageCreate(UInt32(width), UInt32(height), 8, AVIF_PIXEL_FORMAT_YUV444) else {
            throw ImageOperationError.exportFailed
        }
        defer { avifImageDestroy(avifImage) }

        var rgb = avifRGBImage()
        avifRGBImageSetDefaults(&rgb, avifImage)
        rgb.format = AVIF_RGB_FORMAT_RGBA
        rgb.depth = 8
        rgb.alphaPremultiplied = 1
        rgb.pixels = pixels
        rgb.rowBytes = UInt32(bytesPerRow)
        avifImageRGBToYUV(avifImage, &rgb)

        guard let encoder = avifEncoderCreate() else {
            throw ImageOperationError.exportFailed
        }
        defer { avifEncoderDestroy(encoder) }

        let quality = Int32((compressionQuality ?? 0.9) * 100)
        encoder.pointee.speed = 6
        encoder.pointee.maxThreads = Int32(min(ProcessInfo.processInfo.activeProcessorCount, 8))
        encoder.pointee.quality = quality
        encoder.pointee.qualityAlpha = quality

        var raw = avifRWData(data: nil, size: 0)
        let result = avifEncoderWrite(encoder, avifImage, &raw)
        guard result == AVIF_RESULT_OK else {
            if raw.data != nil { avifRWDataFree(&raw) }
            throw ImageOperationError.exportFailed
        }

        guard let rawData = raw.data else {
            throw ImageOperationError.exportFailed
        }
        let data = Data(bytes: rawData, count: raw.size)
        avifRWDataFree(&raw)
        return data
    }
}
