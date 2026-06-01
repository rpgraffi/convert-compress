import CoreGraphics
import Foundation
import XCTest
@testable import convert_compress

final class AVIFEncoderTests: XCTestCase {
    func testDefaultEncodingSettingsFavorInteractiveSpeedAndColorFidelity() {
        XCTAssertEqual(AVIFEncoder.encoderSpeed, 10)
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
}
