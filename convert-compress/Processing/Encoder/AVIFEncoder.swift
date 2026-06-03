import Foundation
import AppKit
import UniformTypeIdentifiers
import avif

struct AVIFEncoder: CustomImageEncoder {
    var supportsMetadataStripping: Bool { false }

    static let encoderSpeed = 6
    static let usesFullRangeColor = true

    func canEncode(utType: UTType) -> Bool {
        utType == .avif
    }

    func encode(cgImage: CGImage, pixelSize: CGSize, utType: UTType, compressionQuality: Double?, stripMetadata: Bool) throws -> Data {
        let image = NSImage(cgImage: cgImage, size: NSSize(width: pixelSize.width, height: pixelSize.height))
        let quality = compressionQuality ?? 0.9
        let options = avif.EncodingOptions(
            quality: quality,
            yuv: .yuv420,
            rangeFull: Self.usesFullRangeColor,
            speed: Self.encoderSpeed,
            preferredCodec: .AOM
        )

        do {
            let data = try avif.AVIFEncoder.encode(image: image, with: options)
            return try ImageMetadataEditor.apply(.appAuthorship, to: data, utType: utType)
        } catch {
            throw ImageOperationError.exportFailed
        }
    }
}
