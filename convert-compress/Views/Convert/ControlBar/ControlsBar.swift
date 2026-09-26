import SwiftUI

struct ControlsBar: View {
    @Environment(PipelineSettingsModule.self) private var settings
    
    var body: some View {
        ControlsBarLayout(spacing: Layout.spacing) {
            PresetButton()
            FormatControl()
            ResizeControl()
            
            if settings.shouldShowCompressionControl {
                QualityControl()
                    .transition(.opacity.combined(with: .scale))
            }
            
            FlipControl()
            RemoveBackgroundControl()
            
            if settings.shouldShowMetadataControl {
                MetadataControl()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(Theme.Animations.spring(), value: settings.selectedFormat)
        .animation(Theme.Animations.spring(), value: settings.resizeMode)
        .animation(Theme.Animations.spring(), value: settings.usesMaxFileSize)
        .animation(Theme.Animations.spring(), value: settings.removeMetadata)
        .animation(Theme.Animations.spring(), value: settings.allowedSquareSizes)
        .animation(Theme.Animations.spring(), value: settings.shouldShowCompressionControl)
        .animation(Theme.Animations.spring(), value: settings.shouldShowMetadataControl)
        .padding(.bottom, 4)
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

/// Like `HStack`, but all pills shrink by the same share of their range, so they reach their minimum together.
private struct ControlsBarLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = widths(for: proposal, subviews)
        let height = zip(subviews, widths)
            .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: proposal.height)).height }
            .max() ?? 0
        return CGSize(width: widths.reduce(0, +) + gaps(subviews), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (view, width) in zip(subviews, widths(for: ProposedViewSize(bounds.size), subviews)) {
            view.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }

    private func widths(for proposal: ProposedViewSize, _ subviews: Subviews) -> [CGFloat] {
        let ranges = subviews.map { view in
            let lower = view.sizeThatFits(ProposedViewSize(width: 0, height: proposal.height)).width
            let upper = view.sizeThatFits(ProposedViewSize(width: .infinity, height: proposal.height)).width
            return (min: lower, max: max(lower, upper))
        }
        let totalMin = ranges.reduce(0) { $0 + $1.min } + gaps(subviews)
        let totalMax = ranges.reduce(0) { $0 + $1.max } + gaps(subviews)
        let available = proposal.width ?? totalMax
        let share = totalMax > totalMin ? ((available - totalMin) / (totalMax - totalMin)).clamped(to: 0...1) : 1
        return ranges.map { $0.min + share * ($0.max - $0.min) }
    }

    private func gaps(_ subviews: Subviews) -> CGFloat {
        spacing * CGFloat(max(subviews.count - 1, 0))
    }
}

extension ControlsBar {
    enum Layout {
        static let spacing: CGFloat = 16
        static let horizontalPadding: CGFloat = 8
    }
}

