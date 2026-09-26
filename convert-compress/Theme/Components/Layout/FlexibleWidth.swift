import SwiftUI

extension View {
    /// Like `.frame(minWidth:maxWidth:)`, but never narrower than the content needs, so the window can grow to fit.
    /// (`.frame(minWidth: 760)` reports 760 even when the content needs 900.)
    func flexibleWidth(min minWidth: CGFloat = 0, max maxWidth: CGFloat = .infinity) -> some View {
        FlexibleWidthLayout(minWidth: minWidth, maxWidth: maxWidth) { self }
    }
}

private struct FlexibleWidthLayout: Layout {
    let minWidth: CGFloat
    let maxWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let minWidth = max(self.minWidth, content.sizeThatFits(ProposedViewSize(width: 0, height: proposal.height)).width)
        let offered = proposal.width ?? content.sizeThatFits(.unspecified).width
        let width = min(max(offered, minWidth), max(minWidth, maxWidth))
        return content.sizeThatFits(ProposedViewSize(width: width, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
