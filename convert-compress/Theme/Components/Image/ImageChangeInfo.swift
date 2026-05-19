import CoreGraphics
import Foundation

struct ImageChangeInfo {
    let resolutionChanged: Bool
    let fileSizeChanged: Bool
    let formatChanged: Bool
    let originalPixelSize: CGSize?
    let targetPixelSize: CGSize?
    let originalFileSize: Int?
    let outputSize: Int?
    let originalFormat: ImageFormat?
    let targetFormat: ImageFormat?

    var hasChanges: Bool {
        resolutionChanged || fileSizeChanged || formatChanged
    }

    @MainActor
    init(asset: ImageAsset, vm: ImageToolsViewModel) {
        self.originalPixelSize = asset.originalPixelSize
        self.targetPixelSize = vm.targetSize(for: asset)
        self.originalFileSize = asset.originalFileSizeBytes
        self.outputSize = vm.outputByteCount(for: asset.id)
        self.originalFormat = ImageIOCapabilities.shared.formatForURL(asset.originalURL)
        self.targetFormat = vm.selectedFormat ?? originalFormat

        self.resolutionChanged = Self.hasResolutionChange(
            from: originalPixelSize,
            to: targetPixelSize
        )
        self.fileSizeChanged = Self.hasFileSizeChange(
            from: originalFileSize,
            to: outputSize
        )
        self.formatChanged = (originalFormat != targetFormat)
    }

    private static func hasResolutionChange(from original: CGSize?, to target: CGSize?) -> Bool {
        guard let original, let target else {
            return false
        }
        return Int(original.width) != Int(target.width) || Int(original.height) != Int(target.height)
    }

    private static func hasFileSizeChange(from original: Int?, to target: Int?) -> Bool {
        guard let original, let target else {
            return false
        }
        return original != target
    }
}
