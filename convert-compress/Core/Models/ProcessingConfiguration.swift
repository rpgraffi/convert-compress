import Foundation

/// Encapsulates all settings for image processing operations
struct ProcessingConfiguration {
    let resizeMode: ResizeMode
    let resizeWidth: String
    let resizeHeight: String
    let resizelongEdge: String
    let selectedFormat: ImageFormat?
    let compressionPercent: Double
    let flipV: Bool
    let removeMetadata: Bool
    let removeBackground: Bool
    let exportDirectory: URL?
    
    init(
        resizeMode: ResizeMode,
        resizeWidth: String,
        resizeHeight: String,
        resizelongEdge: String,
        selectedFormat: ImageFormat?,
        compressionPercent: Double,
        flipV: Bool,
        removeMetadata: Bool,
        removeBackground: Bool,
        exportDirectory: URL? = nil
    ) {
        self.resizeMode = resizeMode
        self.resizeWidth = resizeWidth
        self.resizeHeight = resizeHeight
        self.resizelongEdge = resizelongEdge
        self.selectedFormat = selectedFormat
        self.compressionPercent = compressionPercent
        self.flipV = flipV
        self.removeMetadata = removeMetadata
        self.removeBackground = removeBackground
        self.exportDirectory = exportDirectory
    }
}

