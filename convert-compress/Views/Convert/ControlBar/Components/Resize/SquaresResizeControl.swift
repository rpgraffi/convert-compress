import SwiftUI
import AppKit

/// UI for formats that only support a fixed set of square sizes (e.g., ICNS/ICO).
/// Uses a discrete pill slider across allowed sizes and a menu to pick exact size.
struct SquaresResizeControl: View {
    @Environment(PipelineSettingsModule.self) private var settings
    let allowedSizes: [Int] // sorted ascending
    @State private var menuHandler: MenuHandler?
    @State private var hapticTracker = HapticStopTracker()
    @State private var width: CGFloat = 1
    
    var body: some View {
        discretePercentPill(sizes: allowedSizes)
            .onTapGesture {
                showSizesMenuAtMouseLocation(sizes: allowedSizes)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = max($0, 1) }
    }
    
    private func sizesMenu(_ sizes: [Int]) -> some View {
        Group {
            ForEach(sizes, id: \.self) { s in
                Button("\(s)x\(s)") { selectSquare(s) }
            }
        }
    }
    
    private func selectSquare(_ side: Int) {
        settings.resizeMode = .crop
        settings.resizeWidth = String(side)
        settings.resizeHeight = String(side)
    }
    
    private func discretePercentPill(sizes: [Int]) -> some View {
        let progress = valueToProgress(sizes: sizes)
        return HStack(spacing: 8) {
            Text(String(localized: "Resize"))
                .font(Theme.Fonts.button)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
            Text(currentSizeLabel(sizes: sizes))
                .font(Theme.Fonts.button)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.Metrics.controlHeight)
        // For fixed-size controls we always want the pill filled; never fade out at max
        .background(PillBackground(progress: progress, fadeStart: 2.0))
        .contentShape(Rectangle())
        .horizontalScrollStep(sensitivity: 10.0) { steps in
            let currentIdx = sizes.firstIndex(of: Int(settings.resizeWidth) ?? 0) ?? 0
            let newIdx = (currentIdx + steps).clamped(to: 0...(sizes.count - 1))
            selectSquare(sizes[newIdx])
            hapticTracker.handleStopChange(currentIndex: newIdx)
        }
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    let x = min(max(0, value.location.x), width)
                    let p = Double(x / width)
                    let count = max(sizes.count, 1)
                    let idx = Int((p * Double(count - 1)).rounded())
                    let clampedIdx = min(max(0, idx), count - 1)
                    selectSquare(sizes[clampedIdx])
                    hapticTracker.handleStopChange(currentIndex: clampedIdx)
                }
        )
    }
    
    private func currentSizeLabel(sizes: [Int]) -> String {
        let w = Int(settings.resizeWidth) ?? 0
        let h = Int(settings.resizeHeight) ?? 0
        if w == h && sizes.contains(w) { return "\(w)x\(h)" }
        let nearest = sizes.min(by: { abs($0 - w) < abs($1 - w) }) ?? sizes.first ?? 0
        return "\(nearest)x\(nearest)"
    }
    
    private func valueToProgress(sizes: [Int]) -> Double {
        let current = Int(settings.resizeWidth) ?? sizes.first ?? 0
        guard let idx = sizes.firstIndex(of: current), sizes.count > 1 else { return 0 }
        return Double(idx) / Double(sizes.count - 1)
    }
    
    private func showSizesMenuAtMouseLocation(sizes: [Int]) {
        let handler = MenuHandler { side in
            selectSquare(side)
            self.menuHandler = nil
        }
        self.menuHandler = handler
        
        let menu = NSMenu()
        for s in sizes {
            let item = NSMenuItem(title: "\(s)x\(s)", action: #selector(MenuHandler.handleSelect(_:)), keyEquivalent: "")
            item.target = handler
            item.tag = s
            menu.addItem(item)
        }
        
        let screenPoint = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: screenPoint, in: nil)
    }
}

private final class MenuHandler: NSObject {
    let onSelect: (Int) -> Void
    init(onSelect: @escaping (Int) -> Void) { self.onSelect = onSelect }
    @objc func handleSelect(_ sender: NSMenuItem) { onSelect(sender.tag) }
}


