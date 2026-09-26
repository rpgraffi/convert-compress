import SwiftUI

struct MaxFileSizePill: View {
    @Binding var kilobytes: Int

    @State private var isEditing = false
    @State private var text = ""
    @State private var hapticTracker = HapticStopTracker()
    @State private var width: CGFloat = 1

    private let stops = MaxFileSize.stopsKB

    var body: some View {
        let progress = Double(nearestStopIndex) / Double(stops.count - 1)

        HStack {
            Text(String(localized: "Max Size"))
                .font(Theme.Fonts.button)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                if isEditing {
                    InlineNumberField(text: $text, onCommit: commit)
                        .frame(minWidth: 28, maxWidth: 52)
                } else {
                    Text(MaxFileSize.number(kilobytes))
                        .font(Theme.Fonts.button)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                }

                Text(MaxFileSize.unit(kilobytes))
                    .font(Theme.Fonts.button)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.Metrics.controlHeight)
        .background(PillBackground(progress: progress, fadeStart: .infinity))
        .contentShape(Rectangle())
        .onTapGesture { startEditing() }
        .horizontalScrollStep(sensitivity: 7.0, isEnabled: !isEditing) { steps in
            select((nearestStopIndex + steps).clamped(to: 0...(stops.count - 1)))
        }
        .gesture(
            DragGesture(minimumDistance: 2).onChanged { value in
                guard !isEditing else { return }
                let fraction = Double(value.location.x / width).clamped(to: 0...1)
                select(Int((fraction * Double(stops.count - 1)).rounded()))
            }
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = max($0, 1) }
    }

    private var nearestStopIndex: Int {
        stops.indices.min { abs(stops[$0] - kilobytes) < abs(stops[$1] - kilobytes) } ?? 0
    }

    private func select(_ index: Int) {
        kilobytes = stops[index]
        hapticTracker.handleStopChange(currentIndex: index)
    }

    private func startEditing() {
        guard !isEditing else { return }
        text = MaxFileSize.number(kilobytes)
        isEditing = true
    }

    private func commit() {
        if let typed = MaxFileSize.kilobytes(from: text, shownInMB: MaxFileSize.showsMB(kilobytes)) {
            kilobytes = typed
        }
        isEditing = false
    }
}
