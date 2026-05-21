import SwiftUI

struct InfoOverlay: View {
    let displayInfo: ImageAssetDisplayInfo

    private static let pendingOutputSizeFrameDuration = 0.30

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            formatBadge
            resolutionBadge
            fileSizeBadge
        }
        .padding(6)
        .opacity(displayInfo.hasChanges ? 1 : 0)
    }

    @ViewBuilder
    private var formatBadge: some View {
        if displayInfo.formatChanged,
           let original = displayInfo.originalFormat,
           let target = displayInfo.targetFormat {
            TwoLineOverlayBadge(
                topText: original.displayName,
                bottomText: target.displayName
            )
        }
    }

    @ViewBuilder
    private var resolutionBadge: some View {
        if displayInfo.resolutionChanged,
           let original = displayInfo.originalPixelSize,
           let target = displayInfo.targetPixelSize {
            TwoLineOverlayBadge(
                topText: formatResolution(original),
                bottomText: formatResolution(target, padTo: original)
            )
        }
    }

    @ViewBuilder
    private var fileSizeBadge: some View {
        if let originalSize = displayInfo.originalFileSizeBytes {
            let originalSizeText = FileSizeFormat.string(forByteCount: originalSize)

            if displayInfo.outputStatus == .pending {
                TimelineView(.periodic(from: .now, by: Self.pendingOutputSizeFrameDuration)) { context in
                    fileSizeBadgeContent(
                        originalSizeText: originalSizeText,
                        outputSizeText: Self.pendingOutputSizeText(
                            length: originalSizeText.count,
                            at: context.date
                        )
                    )
                }
            } else {
                fileSizeBadgeContent(
                    originalSizeText: originalSizeText,
                    outputSizeText: outputSizeText
                )
            }
        }
    }

    private func fileSizeBadgeContent(originalSizeText: String, outputSizeText: String) -> some View {
        TwoLineOverlayBadge(
            topText: originalSizeText,
            bottomText: outputSizeText,
            alignment: .trailing
        )
    }

    private static func pendingOutputSizeText(length: Int, at date: Date) -> String {
        guard length > 0 else {
            return ""
        }

        let frameCount = length * 2
        let frameIndex = Int(date.timeIntervalSinceReferenceDate / pendingOutputSizeFrameDuration)
            % frameCount

        if frameIndex <= length {
            let dashCount = length - frameIndex
            return String(repeating: " ", count: frameIndex)
                + String(repeating: "-", count: dashCount)
        }

        let dashCount = frameIndex - length
        return String(repeating: "-", count: dashCount)
            + String(repeating: " ", count: length - dashCount)
    }

    private var outputSizeText: String {
        guard let outputStatus = displayInfo.outputStatus else {
            return "--- KB"
        }

        switch outputStatus {
        case .pending:
            return "--- KB"
        case .ready(let byteCount):
            return FileSizeFormat.string(forByteCount: byteCount)
        case .failed:
            return String(localized: "Error")
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
