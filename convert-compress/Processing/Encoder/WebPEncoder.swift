import Foundation
import AppKit
import UniformTypeIdentifiers
import SDWebImage
import SDWebImageWebPCoder
import libwebp

struct WebPEncoder: CustomImageEncoder {
    var supportsMetadataStripping: Bool { false }

    func canEncode(utType: UTType) -> Bool {
        return utType == UTType.webP
    }

    func encode(cgImage: CGImage, pixelSize: CGSize, utType: UTType, compressionQuality: Double?, stripMetadata: Bool) throws -> Data {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: pixelSize.width, height: pixelSize.height))
        var options: [SDImageCoderOption: Any] = [:]
        if let q = compressionQuality { options[.encodeCompressionQuality] = q }
        options[.encodeWebPMethod] = 0.5
        guard let data = SDImageWebPCoder.shared.encodedData(with: nsImage, format: .webP, options: options) else {
            throw ImageOperationError.exportFailed
        }
        // WebP without a profile means sRGB, so only non-sRGB images need one.
        guard let colorSpace = cgImage.colorSpace, colorSpace.name != CGColorSpace.sRGB,
              let icc = colorSpace.copyICCData() as Data? else {
            return data
        }
        return Self.embeddingICCProfile(icc, into: data)
    }

    /// SDWebImageWebPCoder keeps pixels in the image's color space but never writes the profile.
    /// libwebp's mux adds the ICCP chunk (and the extended header it needs).
    static func embeddingICCProfile(_ icc: Data, into webp: Data) -> Data {
        webp.withUnsafeBytes { webpBytes in
            icc.withUnsafeBytes { iccBytes in
                var image = WebPData(bytes: webpBytes.bindMemory(to: UInt8.self).baseAddress, size: webp.count)
                var profile = WebPData(bytes: iccBytes.bindMemory(to: UInt8.self).baseAddress, size: icc.count)
                guard let mux = WebPMuxCreate(&image, 0) else { return webp }
                defer { WebPMuxDelete(mux) }
                var output = WebPData()
                guard WebPMuxSetChunk(mux, "ICCP", &profile, 0) == WEBP_MUX_OK,
                      WebPMuxAssemble(mux, &output) == WEBP_MUX_OK else { return webp }
                defer { WebPDataClear(&output) }
                return Data(bytes: output.bytes, count: output.size)
            }
        }
    }
}
