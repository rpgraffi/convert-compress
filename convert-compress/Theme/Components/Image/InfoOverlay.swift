import SwiftUI

struct InfoOverlay: View {
    let displayInfo: ImageAssetDisplayInfo

    private static let pendingOutputSizeFrameDuration = 0.10
    private static let pendingBrailleNoiseFrames = [
        "⠞⠃⣴⠏⢀⡼⠋⣰⡟",
        "⠟⢁⣾⠏⢀⠞⠃⣴⡟",
        "⠛⢁⣾⠃⣠⠞⠁⣼⠏",
        "⠋⢠⡾⠃⣠⠟⢁⣾⠏",
        "⠋⢠⡿⢁⣴⠋⢀⡾⠃",
        "⠁⣰⠟⢁⣴⠋⢠⡿⢃",
        "⠁⣰⠟⢠⡶⠁⢠⠿⢁",
        "⠀⡼⠟⣠⡾⠁⣰⠟⢡",
        "⢀⡼⠋⣰⡞⠀⣰⠟⢠",
        "⢀⡼⠋⣴⡟⢀⡼⠋⣰",
        "⣠⠞⠁⣴⠏⢀⡼⠋⣰",
        "⣠⠞⢁⣾⠏⣠⡜⠁⣴",
        "⣤⠊⢁⣾⠃⣠⠞⠁⣼",
        "⣴⠊⢀⡿⢃⣤⠎⢀⣾",
        "⣴⠀⢠⡿⢃⣴⠂⢀⡾",
        "⡶⠀⣠⠟⢁⣴⠂⢀⡾",
        "⡶⠀⣠⠟⢡⣶⠀⢠⠟",
        "⡖⠀⡰⠛⣡⡶⠀⣠⠟",
        "⡞⢀⡐⠋⣱⡶⠀⡠⠛",
        "⠟⢀⡀⠋⣱⡾⢀⡀⠋",
        "⠟⣀⠄⠉⣴⠟⢀⡀⠉",
        "⠏⣠⠀⠉⣴⠟⣀⡄⠉",
        "⢏⣠⠀⠁⡴⠟⣠⡄⠉",
        "⢋⣤⠀⠁⡼⠟⣠⡄⠁",
        "⢋⣤⠊⠀⠼⢟⣤⠄⠁",
        "⢋⣴⠊⠀⠼⢋⣤⠎⠀",
        "⢣⣴⠋⠀⠜⢋⣴⠎⠀",
        "⢡⣶⠃⠀⠚⢋⣴⠏⠀",
        "⢡⣾⠃⡀⠚⢁⣶⠏⢀",
        "⢠⡾⢁⡠⠛⢁⣾⠇⣀",
        "⢰⡿⢁⡠⠋⢠⣾⢃⣠",
        "⣰⡿⢁⡴⠋⢠⡿⢃⣠",
        "⣰⠟⣀⡴⠁⢰⠿⢁⣴",
        "⡼⠟⣠⡞⠁⢰⠟⢁⡴",
        "⡼⠋⣠⡞⠁⡰⠟⣠⡾",
        "⡾⠋⣴⡟⠀⡼⠋⣠⡾"
    ]

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

            switch displayInfo.outputStatus {
            case nil, .pending:
                TimelineView(.periodic(from: .now, by: Self.pendingOutputSizeFrameDuration)) { context in
                    pendingFileSizeBadgeContent(
                        originalSizeText: originalSizeText,
                        outputSizeText: Self.pendingOutputSizeText(
                            length: originalSizeText.count,
                            at: context.date
                        )
                    )
                }
            case .ready(let byteCount):
                fileSizeBadgeContent(
                    originalSizeText: originalSizeText,
                    outputSizeText: FileSizeFormat.string(forByteCount: byteCount)
                )
            case .failed:
                fileSizeBadgeContent(
                    originalSizeText: originalSizeText,
                    outputSizeText: String(localized: "Error")
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

    @ViewBuilder
    private func pendingFileSizeBadgeContent(originalSizeText: String, outputSizeText: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(originalSizeText)
                .foregroundStyle(.secondary)
            Text(originalSizeText)
                .hidden()
                .overlay(alignment: .trailing) {
                    Text(outputSizeText)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .clipped()
        }
        .font(Theme.Fonts.captionMono)
        .monospaced(true)
        .padding(6)
        .background(OverlayBackground(cornerRadius: 6))
    }

    private static func pendingOutputSizeText(length: Int, at date: Date) -> String {
        guard length > 0 else {
            return ""
        }

        let frameIndex = Int(date.timeIntervalSinceReferenceDate / pendingOutputSizeFrameDuration)
            % pendingBrailleNoiseFrames.count

        return Self.withCharacterCount(pendingBrailleNoiseFrames[frameIndex], length)
    }

    private static func withCharacterCount(_ text: String, _ length: Int) -> String {
        if text.count > length {
            return String(text.prefix(length))
        }
        if text.count < length {
            return text + String(repeating: " ", count: length - text.count)
        }
        return text
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
