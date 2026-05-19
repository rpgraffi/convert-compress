import Foundation
import CoreImage
import AppKit
import UniformTypeIdentifiers
import ImageIO

struct ProcessedImageEncoder {
    private static let sharedCIContext: CIContext = {
        CIContext()
    }()

    // MARK: - DRY helpers

    private static func decideActualUTType(originalURL: URL, requestedFormat: ImageFormat?) -> UTType {
        requestedFormat?.utType
            ?? ImageIOCapabilities.shared.formatForURL(originalURL)?.utType
            ?? .png
    }

    // Exposed helper for planning destination names without doing any encode work
    static func decideUTTypeForExport(originalURL: URL, requestedFormat: ImageFormat?) -> UTType {
        decideActualUTType(originalURL: originalURL, requestedFormat: requestedFormat)
    }

    private static func buildDestinationProperties(originalURL: URL, actualUTI: UTType, compressionQuality: Double?, stripMetadata: Bool) -> [CFString: Any] {
        var props: [CFString: Any] = [:]
        if !stripMetadata {
            if let source = CGImageSourceCreateWithURL(originalURL as CFURL, nil),
               let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                for (key, value) in metadata { props[key] = value }
            }
        }
        props[kCGImagePropertyOrientation] = 1
        if var tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            props[kCGImagePropertyTIFFDictionary] = tiff
        }
        if actualUTI == .jpeg || actualUTI == UTType.heic {
            props[kCGImageDestinationLossyCompressionQuality] = compressionQuality ?? 0.9
        }
        return props
    }

    static func encodeToData(ciImage: CIImage, originalURL: URL, format: ImageFormat?, compressionQuality: Double?, stripMetadata: Bool = false) throws -> (data: Data, uti: UTType) {
        let actualUTI = decideActualUTType(originalURL: originalURL, requestedFormat: format)
        let ciContext = ProcessedImageEncoder.sharedCIContext
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw ImageOperationError.exportFailed
        }
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: colorSpace) else {
            throw ImageOperationError.exportFailed
        }

        if let encoder = CustomImageEncoderRegistry.encoder(for: actualUTI) {
            let size = CGSize(width: ciImage.extent.width, height: ciImage.extent.height)
            if stripMetadata && !encoder.supportsMetadataStripping {
                AppLogger.export.warning("Metadata stripping is not supported by custom encoder for \(actualUTI.identifier, privacy: .public)")
            }
            let data = try encoder.encode(
                cgImage: cgImage,
                pixelSize: size,
                utType: actualUTI,
                compressionQuality: compressionQuality,
                stripMetadata: stripMetadata && encoder.supportsMetadataStripping
            )
            return (data, actualUTI)
        }

        let props = buildDestinationProperties(originalURL: originalURL, actualUTI: actualUTI, compressionQuality: compressionQuality, stripMetadata: stripMetadata)
        guard let cfData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(cfData, actualUTI.identifier as CFString, 1, nil) else {
            throw ImageOperationError.exportFailed
        }
        CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ImageOperationError.exportFailed }
        let data = cfData as Data
        return (data, actualUTI)
    }
}
