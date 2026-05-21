import CoreGraphics
import Foundation

enum ImageOutputDisplayStatus: Equatable {
    case pending
    case ready(byteCount: Int)
    case failed

    var outputByteCount: Int? {
        guard case .ready(let byteCount) = self else {
            return nil
        }
        return byteCount
    }
}

struct ImageAssetDisplayInfo {
    let originalPixelSize: CGSize?
    let targetPixelSize: CGSize?
    let originalFileSizeBytes: Int?
    let outputStatus: ImageOutputDisplayStatus?
    let originalFormat: ImageFormat?
    let targetFormat: ImageFormat?

    var outputByteCount: Int? {
        outputStatus?.outputByteCount
    }

    var hasChanges: Bool {
        resolutionChanged || fileSizeChanged || formatChanged || outputFailed
    }

    var resolutionChanged: Bool {
        guard let originalPixelSize, let targetPixelSize else {
            return false
        }
        return Int(originalPixelSize.width) != Int(targetPixelSize.width)
            || Int(originalPixelSize.height) != Int(targetPixelSize.height)
    }

    var fileSizeChanged: Bool {
        outputByteDifference != nil
    }

    var formatChanged: Bool {
        originalFormat != targetFormat
    }

    var outputFailed: Bool {
        outputStatus == .failed
    }

    var outputByteDifference: Int? {
        guard let originalFileSizeBytes,
              let outputByteCount,
              originalFileSizeBytes != outputByteCount else {
            return nil
        }
        return originalFileSizeBytes - outputByteCount
    }

    var outputByteChangePercent: Int? {
        guard let outputByteDifference,
              let originalFileSizeBytes,
              originalFileSizeBytes > 0 else {
            return nil
        }
        return Int(round(Double(abs(outputByteDifference)) / Double(originalFileSizeBytes) * 100))
    }

    init(
        asset: ImageAsset,
        targetPixelSize: CGSize?,
        outputStatus: ImageOutputDisplayStatus?,
        selectedFormat: ImageFormat?
    ) {
        self.originalPixelSize = asset.originalPixelSize
        self.targetPixelSize = targetPixelSize
        self.originalFileSizeBytes = asset.originalFileSizeBytes
        self.outputStatus = outputStatus
        self.originalFormat = asset.originalFormat
        self.targetFormat = selectedFormat ?? asset.originalFormat
    }
}
