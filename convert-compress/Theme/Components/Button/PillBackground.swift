import SwiftUI

struct PillBackground: View {
    let progress: Double // 0...1
    var fadeStart: Double = 0.95

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let clampedProgress = max(0.0, min(1.0, progress))
            let p = CGFloat(clampedProgress)
            let fadeStartCGFloat = CGFloat(fadeStart)
            let fillOpacity: CGFloat = p < fadeStartCGFloat
                ? 1.0
                : max(0.0, (1.0 - (p - fadeStartCGFloat) / (1.0 - fadeStartCGFloat)))

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.Colors.controlBackground)

                Rectangle()
                    .fill(Color.accentColor)
                    .opacity(fillOpacity)
                    .frame(width: max(0, width * p))
                    .animation(Theme.Animations.pillFill(), value: clampedProgress)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.pillCornerRadius(forHeight: geo.size.height), style: .continuous))
        }
    }
}
