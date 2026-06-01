import Foundation
import XCTest
@testable import convert_compress

@MainActor
final class AssetCollectionModuleTests: XCTestCase {
    func testClearAllResetsIngestionProgressImmediately() {
        let assets = AssetCollectionModule()
        assets.images = [ImageAsset(url: URL(fileURLWithPath: "/tmp/source.png"))]
        assets.ingestionProgress.addToTotal(3)
        assets.ingestionProgress.increment()

        assets.clearAll()

        XCTAssertEqual(assets.ingestionProgress, ProgressState())
    }
}
