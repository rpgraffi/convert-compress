import SwiftUI

struct StrikePillToggle<LabelContent: View>: View {
    @Binding var isOn: Bool
    var highlightedFill: Color = .accentColor
    var normalFill: Color = Theme.Colors.controlBackground
    let label: () -> LabelContent
    @State private var textWidth: CGFloat = 0
    @State private var strikeAnchor: UnitPoint
    @State private var isStrikeVisible: Bool

    init(
        isOn: Binding<Bool>,
        highlightedFill: Color = .accentColor,
        normalFill: Color = Theme.Colors.controlBackground,
        @ViewBuilder label: @escaping () -> LabelContent
    ) {
        self._isOn = isOn
        self.highlightedFill = highlightedFill
        self.normalFill = normalFill
        self.label = label
        self._strikeAnchor = State(initialValue: isOn.wrappedValue ? .leading : .trailing)
        self._isStrikeVisible = State(initialValue: isOn.wrappedValue)
    }

    var body: some View {
        BasePillToggle(isOn: $isOn, highlightedFill: highlightedFill, normalFill: normalFill) { isOn in
            let baseLabel = label()
                .font(Theme.Fonts.button)
                .lineLimit(1)
                .foregroundStyle(isOn ? Color.white : .primary)

            baseLabel
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: _TextWidthPreferenceKey.self, value: proxy.size.width)
                    }
                )
                .overlay(alignment: .center) {
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: textWidth, height: 2)
                        .scaleEffect(x: isStrikeVisible ? 1.0 : 0.0, y: 1.0, anchor: strikeAnchor)
                }
                .onPreferenceChange(_TextWidthPreferenceKey.self) { newWidth in
                    textWidth = newWidth
                }
                .padding(.horizontal, 12)
        }
        .onChange(of: isOn) { _, newValue in
            updateStrikeState(isOn: newValue)
        }
    }

    private func updateStrikeState(isOn: Bool) {
        var instantTransaction = Transaction()
        instantTransaction.disablesAnimations = true

        withTransaction(instantTransaction) {
            strikeAnchor = isOn ? .leading : .trailing
        }

        withAnimation(Theme.Animations.spring()) {
            isStrikeVisible = isOn
        }
    }
}

private struct _TextWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct StrikePillTogglePreviewWrapper: View {
    @State var isOn: Bool = false
    var body: some View {
        VStack(spacing: 16) {
            StrikePillToggle(isOn: $isOn) {
                Text("Metadata")
            }
            .help("Toggle metadata removal")

            PillToggle(isOn: $isOn) {
                Text("Metadata")
            }
        }
        .padding()
    }
}

#Preview("StrikePillToggle") {
    StrikePillTogglePreviewWrapper()
        .frame(width: 300)
}

