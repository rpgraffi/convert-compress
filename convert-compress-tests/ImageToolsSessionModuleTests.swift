import Foundation
import XCTest
@testable import convert_compress

@MainActor
final class ImageToolsSessionModuleTests: XCTestCase {
    func testClearAllCoordinatesWorkTeardown() {
        let modules = makeModules()
        let asset = ImageAsset(url: URL(fileURLWithPath: "/tmp/source.png"))
        let configuration = modules.settings.currentConfiguration

        modules.assets.images = [asset]
        modules.assets.ingestionProgress.addToTotal(2)
        modules.assets.ingestionProgress.increment()
        modules.encodedOutput.cache.markPending(assetIDs: [asset.id], configuration: configuration)
        modules.comparison.presentComparison(for: asset)

        modules.session.clearAll()

        XCTAssertTrue(modules.assets.images.isEmpty)
        XCTAssertEqual(modules.assets.ingestionProgress, ProgressState())
        XCTAssertNil(modules.encodedOutput.cache.freshStatus(for: asset.id, configuration: configuration))
        XCTAssertNil(modules.comparison.comparisonSelection)
    }

    func testRemoveAssetCoordinatesDependentState() {
        let modules = makeModules()
        let asset = ImageAsset(url: URL(fileURLWithPath: "/tmp/source.png"))
        let configuration = modules.settings.currentConfiguration

        modules.assets.images = [asset]
        modules.encodedOutput.cache.markPending(assetIDs: [asset.id], configuration: configuration)
        modules.comparison.presentComparison(for: asset)

        modules.session.remove(asset)

        XCTAssertTrue(modules.assets.images.isEmpty)
        XCTAssertNil(modules.encodedOutput.cache.freshStatus(for: asset.id, configuration: configuration))
        XCTAssertNil(modules.comparison.comparisonSelection)
    }

    private func makeModules() -> ImageToolsModules {
        ImageToolsModules()
    }
}
