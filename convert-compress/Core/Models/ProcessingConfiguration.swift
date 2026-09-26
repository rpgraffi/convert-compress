import Foundation

/// Encapsulates all settings for image processing operations.
struct ProcessingConfiguration: Codable, Equatable {
    let resizeMode: ResizeMode
    let resizeWidth: String
    let resizeHeight: String
    let resizeLongEdge: String
    let selectedFormat: ImageFormat?
    let compressionPercent: Double
    let flipV: Bool
    let removeMetadata: Bool
    let removeBackground: Bool
    /// nil = quality mode. Optional so older presets still decode.
    var maxFileSizeKB: Int? = nil

    var resizeSpecification: ResizeSpecification {
        ResizeSpecification(
            mode: resizeMode,
            widthText: resizeWidth,
            heightText: resizeHeight,
            longEdgeText: resizeLongEdge
        )
    }
}
