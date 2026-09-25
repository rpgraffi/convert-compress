import CoreImage
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import convert_compress

final class ColorProfileExportTests: XCTestCase {
    func testExportKeepsSourceColorProfile() throws {
        let adobeRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.adobeRGB1998))
        let pixels = Data((0..<(4 * 4)).flatMap { _ in [200, 40, 40, 255] as [UInt8] })
        let image = CIImage(bitmapData: pixels, bytesPerRow: 4 * 4, size: CGSize(width: 4, height: 4), format: .RGBA8, colorSpace: adobeRGB)
        let sourceURL = URL(fileURLWithPath: "/tmp/source.jpg")

        for utType in [UTType.jpeg, .png, .webP] {
            for stripMetadata in [false, true] {
                let encoded = try ProcessedImageEncoder.encodeToData(
                    ciImage: image,
                    originalURL: sourceURL,
                    format: ImageFormat(utType: utType),
                    compressionQuality: 0.9,
                    stripMetadata: stripMetadata
                )
                let source = try XCTUnwrap(CGImageSourceCreateWithData(encoded.data as CFData, nil))
                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
                XCTAssertEqual(
                    properties?[kCGImagePropertyProfileName] as? String,
                    "Adobe RGB (1998)",
                    "\(utType.identifier), stripMetadata: \(stripMetadata)"
                )
            }
        }
    }
}
