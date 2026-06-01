import SwiftUI

/// Reusable percent slider pill with inline editing, drag interaction, scroll, and optional haptics.
struct PercentPill: View {
    let label: String
    @Binding var value01: Double
    let dragStep: Double
    let showsTenPercentHaptics: Bool
    let showsFullBoundaryHaptic: Bool

    @State private var isEditing = false
    @State private var percentString = "100"
    @State private var didHapticAtFull = false
    @State private var lastTenPercentTick: Int?

    var body: some View {
        GeometryReader { geo in
            let progress = value01.clamped(to: 0...1)
            
            ZStack(alignment: .leading) {
                PillBackground(
                    containerSize: geo.size,
                    cornerRadius: Theme.Metrics.pillCornerRadius(forHeight: geo.size.height),
                    progress: progress
                )
                
                HStack {
                    Text(label)
                        .font(Theme.Fonts.button)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if isEditing {
                            InlineNumberField(
                                text: $percentString,
                                onCommit: commitPercent
                            )
                            .frame(minWidth: 28, maxWidth: 44)
                        } else {
                            Text("\(percent(for: progress))")
                                .font(Theme.Fonts.button)
                                .monospacedDigit()
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        Text("%")
                            .font(Theme.Fonts.button)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 12)
            }
            .contentShape(Rectangle())
            .onTapGesture { startEditing(progress: progress) }
            .horizontalScrollStep(
                isEnabled: !isEditing
            ) { steps in
                let target = value01 + Double(steps) * dragStep
                updateValue(snapped(target))
            }
            .gesture(dragGesture(width: geo.size.width))
            .onAppear { percentString = "\(percent(for: progress))" }
        }
    }
    
    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2).onChanged { value in
            guard !isEditing else { return }
            let x = value.location.x.clamped(to: 0...width)
            updateValue(snapped(x / width))
        }
    }
    
    private func startEditing(progress: Double) {
        guard !isEditing else { return }
        isEditing = true
        percentString = "\(percent(for: progress))"
    }
    
    private func commitPercent() {
        let value = (Int(percentString) ?? percent(for: value01)).clamped(to: 0...100)
        percentString = "\(value)"
        updateValue(Double(value) / 100)
        isEditing = false
    }
    
    /// Rounds a 0...1 progress to a whole-percent integer, avoiding the floating-point
    /// truncation that made values land one step low (e.g. `Int(0.35 * 100) == 34`).
    private func percent(for progress: Double) -> Int {
        Int((progress * 100).rounded())
    }
    
    /// Snaps a 0...1 value to the nearest `dragStep` increment, clamped to 0...1.
    /// Keeps repeated scroll increments locked to the step grid instead of drifting.
    private func snapped(_ value: Double) -> Double {
        ((value / dragStep).rounded() * dragStep).clamped(to: 0...1)
    }
    
    private func updateValue(_ newValue: Double) {
        value01 = newValue
        triggerHaptics(for: newValue)
    }
    
    private func triggerHaptics(for progress: Double) {
        if showsFullBoundaryHaptic && progress >= 1.0 && !didHapticAtFull {
            Haptics.levelChange()
            didHapticAtFull = true
        } else if progress < 1.0 {
            didHapticAtFull = false
        }
        
        if showsTenPercentHaptics {
            let tick = percent(for: progress)
            if tick % 10 == 0 && tick > 0 && tick < 100 && lastTenPercentTick != tick {
                Haptics.alignment()
                lastTenPercentTick = tick
            } else if tick % 10 != 0 {
                lastTenPercentTick = nil
            }
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
} 
