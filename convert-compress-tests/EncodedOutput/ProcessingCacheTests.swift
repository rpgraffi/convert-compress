import XCTest
import UniformTypeIdentifiers
@testable import convert_compress

final class ProcessingCacheTests: XCTestCase {
    func testPendingEntriesAreEligibleForProcessing() {
        var cache = ProcessingCache()
        let assetID = UUID()
        let configuration = makeConfiguration(width: "100")

        cache.markPending(assetIDs: [assetID], configuration: configuration)

        XCTAssertTrue(cache.needsProcessing(for: assetID, configuration: configuration))
    }

    func testRemovePendingOnlyRemovesMatchingConfiguration() {
        var cache = ProcessingCache()
        let assetID = UUID()
        let originalConfiguration = makeConfiguration(width: "100")
        let newConfiguration = makeConfiguration(width: "200")

        cache.markPending(assetIDs: [assetID], configuration: originalConfiguration)
        cache.removePending(assetIDs: [assetID], configuration: newConfiguration)

        XCTAssertNotNil(cache.freshStatus(for: assetID, configuration: originalConfiguration))

        cache.removePending(assetIDs: [assetID], configuration: originalConfiguration)

        XCTAssertNil(cache.freshStatus(for: assetID, configuration: originalConfiguration))
    }

    func testReadyAndFailedEntriesDoNotNeedProcessingForFreshConfiguration() {
        var cache = ProcessingCache()
        let assetID = UUID()
        let configuration = makeConfiguration(width: "100")
        let staleConfiguration = makeConfiguration(width: "200")
        let data = ProcessedImageData(data: Data([1]), uti: .png, configuration: configuration)

        cache.storeReady(data, forKey: assetID)

        XCTAssertFalse(cache.needsProcessing(for: assetID, configuration: configuration))
        XCTAssertTrue(cache.needsProcessing(for: assetID, configuration: staleConfiguration))

        cache.storeFailure(forKey: assetID, configuration: configuration)

        XCTAssertFalse(cache.needsProcessing(for: assetID, configuration: configuration))
    }

    private func makeConfiguration(width: String) -> ProcessingConfiguration {
        ProcessingConfiguration(
            resizeMode: .resize,
            resizeWidth: width,
            resizeHeight: "",
            resizeLongEdge: "",
            selectedFormat: nil,
            compressionPercent: 0.8,
            flipV: false,
            removeMetadata: false,
            removeBackground: false
        )
    }
}
