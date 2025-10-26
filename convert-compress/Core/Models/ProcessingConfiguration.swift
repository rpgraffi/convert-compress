import Foundation

/// Encapsulates all settings for image processing operations
struct ProcessingConfiguration: Codable {
    let resizeMode: ResizeMode
    let resizeWidth: String
    let resizeHeight: String
    let resizeLongEdge: String
    let selectedFormat: ImageFormat?
    let compressionPercent: Double
    let flipV: Bool
    let removeMetadata: Bool
    let removeBackground: Bool
}

