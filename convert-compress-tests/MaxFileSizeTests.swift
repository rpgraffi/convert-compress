import CoreImage
import UniformTypeIdentifiers
import XCTest
@testable import convert_compress

final class MaxFileSizeTests: XCTestCase {
    func testSearchPicksBestQualityUnderLimit() throws {
        let image = try noiseImage(side: 256)
        let url = URL(fileURLWithPath: "/tmp/source.png")

        for utType in [UTType.jpeg, .webP] {
            let rendered = try ProcessedImageEncoder.render(ciImage: image, originalURL: url, format: ImageFormat(utType: utType))
            func size(limit: Int) throws -> Int {
                try MaxFileSize.fit(maxByteCount: limit, encode: rendered.encode).count
            }
            let top = try rendered.encode(MaxFileSize.qualityRange.upperBound).count
            let bottom = try rendered.encode(MaxFileSize.qualityRange.lowerBound).count
            let limit = (top + bottom) / 2

            let fitted = try size(limit: limit)
            XCTAssertLessThanOrEqual(fitted, limit, utType.identifier)
            XCTAssertGreaterThan(fitted, bottom, utType.identifier)
            XCTAssertEqual(try size(limit: top), top, "fits at top quality: \(utType.identifier)")
            XCTAssertEqual(try size(limit: 1), bottom, "can't fit, smallest file: \(utType.identifier)")
        }
    }

    func testTypedSizeUsesShownUnitUnlessOneIsTyped() {
        XCTAssertEqual(MaxFileSize.kilobytes(from: "500", shownInMB: false), 500)
        XCTAssertEqual(MaxFileSize.kilobytes(from: "2", shownInMB: true), 2048)
        XCTAssertEqual(MaxFileSize.kilobytes(from: "1.5mb", shownInMB: false), 1536)
        XCTAssertEqual(MaxFileSize.kilobytes(from: "1,5 M", shownInMB: false), 1536)
        XCTAssertEqual(MaxFileSize.kilobytes(from: "300 KB", shownInMB: true), 300)
        XCTAssertEqual(MaxFileSize.kilobytes(from: "20 MB", shownInMB: false), 20480)
        XCTAssertNil(MaxFileSize.kilobytes(from: "abc", shownInMB: false))
        XCTAssertNil(MaxFileSize.kilobytes(from: "0", shownInMB: false))
        XCTAssertNil(MaxFileSize.kilobytes(from: "99999999999999999999 mb", shownInMB: false))
    }

    func testPresetsSavedWithoutMaxFileSizeStillDecode() throws {
        let old = #"{"resizeMode":"resize","resizeWidth":"","resizeHeight":"","resizeLongEdge":"","compressionPercent":0.8,"flipV":false,"removeMetadata":false,"removeBackground":false}"#
        let configuration = try JSONDecoder().decode(ProcessingConfiguration.self, from: Data(old.utf8))
        XCTAssertNil(configuration.maxFileSizeKB)
    }

    private func noiseImage(side: Int) throws -> CIImage {
        var seed: UInt32 = 1
        let pixels = Data((0..<(side * side)).flatMap { _ -> [UInt8] in
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return [UInt8(truncatingIfNeeded: seed >> 24), UInt8(truncatingIfNeeded: seed >> 16), UInt8(truncatingIfNeeded: seed >> 8), 255]
        })
        let sRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        return CIImage(bitmapData: pixels, bytesPerRow: side * 4, size: CGSize(width: side, height: side), format: .RGBA8, colorSpace: sRGB)
    }
}
