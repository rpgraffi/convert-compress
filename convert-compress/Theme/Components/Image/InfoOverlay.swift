import SwiftUI

struct InfoOverlay: View {
    let changeInfo: ImageChangeInfo

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            formatBadge
            resolutionBadge
            fileSizeBadge
        }
        .padding(6)
        .opacity(changeInfo.hasChanges ? 1 : 0)
    }

    @ViewBuilder
    private var formatBadge: some View {
        if changeInfo.formatChanged,
           let original = changeInfo.originalFormat,
           let target = changeInfo.targetFormat {
            TwoLineOverlayBadge(
                topText: original.displayName,
                bottomText: target.displayName
            )
        }
    }

    @ViewBuilder
    private var resolutionBadge: some View {
        if changeInfo.resolutionChanged,
           let original = changeInfo.originalPixelSize,
           let target = changeInfo.targetPixelSize {
            TwoLineOverlayBadge(
                topText: formatResolution(original),
                bottomText: formatResolution(target, padTo: original)
            )
        }
    }

    @ViewBuilder
    private var fileSizeBadge: some View {
        if let originalSize = changeInfo.originalFileSize {
            TwoLineOverlayBadge(
                topText: FileSizeFormat.string(forByteCount: originalSize),
                bottomText: changeInfo.estimatedOutputSize.map { FileSizeFormat.string(forByteCount: $0) } ?? "--- KB",
                alignment: .trailing
            )
        }
    }

    private func formatResolution(_ size: CGSize, padTo reference: CGSize? = nil) -> String {
        let width = Int(size.width)
        let height = Int(size.height)

        guard let reference else {
            return "\(width)×\(height)"
        }

        let referenceWidth = String(Int(reference.width))
        let referenceHeight = String(Int(reference.height))
        let widthString = String(width)
        let heightString = String(height)

        let widthPadding = max(0, referenceWidth.count - widthString.count)
        let heightPadding = max(0, referenceHeight.count - heightString.count)

        let paddedWidth = String(repeating: " ", count: widthPadding) + widthString
        let paddedHeight = String(repeating: " ", count: heightPadding) + heightString

        return "\(paddedWidth)×\(paddedHeight)"
    }
}
