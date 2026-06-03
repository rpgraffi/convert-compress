import CoreGraphics
import Foundation
import XCTest
@testable import convert_compress

final class AVIFEncoderTests: XCTestCase {
    func testDefaultEncodingSettingsFavorInteractiveSpeedAndColorFidelity() {
        XCTAssertEqual(AVIFEncoder.encoderSpeed, 6)
        XCTAssertTrue(AVIFEncoder.usesFullRangeColor)
    }

    func testEncodeProducesAVIFData() throws {
        let width = 2
        let height = 2
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let image = try makeCGImage(
            rgbaBytes: [
                255, 0, 0, 255, 0, 255, 0, 255,
                0, 0, 255, 255, 255, 255, 255, 255
            ],
            width: width,
            height: height,
            colorSpace: colorSpace
        )

        let data = try AVIFEncoder().encode(
            cgImage: image,
            pixelSize: CGSize(width: width, height: height),
            utType: .avif,
            compressionQuality: 0.8,
            stripMetadata: false
        )

        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(String(data: data[4..<8], encoding: .ascii), "ftyp")

        let decodedBytes = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(decodedBytes.contains("awxkee/avif.swift"))
        XCTAssertFalse(decodedBytes.contains("avif.swift"))
        XCTAssertTrue(decodedBytes.contains("Convert &amp; Compress"))
    }

    func testAppAuthorshipMetadataReplacesPackageXMPFieldsInPlace() throws {
        let originalData = Data(("prefix" + packageXMPPacket + "suffix").utf8)

        let updatedData = try ImageMetadataEditor.apply(.appAuthorship, to: originalData, utType: .avif)
        let updatedPacket = String(decoding: updatedData, as: UTF8.self)

        XCTAssertEqual(updatedData.count, originalData.count)
        XCTAssertFalse(updatedPacket.contains("awxkee/avif.swift"))
        XCTAssertFalse(updatedPacket.contains("avif.swift"))
        XCTAssertFalse(updatedPacket.contains("<dc:publisher>"))
        XCTAssertTrue(updatedPacket.contains("Convert &amp; Compress"))
    }

    private func makeCGImage(rgbaBytes: [UInt8], width: Int, height: Int, colorSpace: CGColorSpace) throws -> CGImage {
        let bytesPerRow = width * 4
        let data = Data(rgbaBytes) as CFData
        let provider = try XCTUnwrap(CGDataProvider(data: data))
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )
        return try XCTUnwrap(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
    }

    private var packageXMPPacket: String {
        "<?xpacket begin='' id='W5M0MpCehiHzreSzNTczkc9d'?>"
            + "<x:xmpmeta xmlns:x='adobe:ns:meta/' x:xmptk='XMP Core 5.5.0'>"
            + "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>"
            + "<rdf:Description rdf:about='' xmlns:dc='http://purl.org/dc/elements/1.1/'>"
            + "<dc:title>Generated image by avif.swift</dc:title>"
            + "<dc:creator>avif.swift</dc:creator>"
            + "<dc:description>A image was created by avif.swift (https://github.com/awxkee/avif.swift)</dc:description>"
            + "<dc:date>2026:06:03 10:56:00</dc:date>"
            + "<dc:publisher>https://github.com/awxkee/avif.swift</dc:publisher>"
            + "<dc:format>AVIF</dc:format>"
            + "</rdf:Description>"
            + "<rdf:Description rdf:about='' xmlns:xmp='http://ns.adobe.com/xap/1.0/'>"
            + "<xmp:CreatorTool>avif.swift (https://github.com/awxkee/avif.swift)</xmp:CreatorTool>"
            + "<xmp:ModifyDate>2026:06:03 10:56:00</xmp:ModifyDate>"
            + "</rdf:Description>"
            + "</rdf:RDF>"
            + "</x:xmpmeta>"
            + "<?xpacket end='w'?>"
    }
}
