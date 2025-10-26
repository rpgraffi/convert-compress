import SwiftUI
import AppKit

struct PresetButton: View {
    @State private var isPopoverShown = false
    
    var body: some View {
        CircleIconButton() {
            isPopoverShown.toggle()
        } label: {
            Image(systemName: "square.3.stack.3d.top.fill")
        }
        .help("Presets")
        .popover(isPresented: $isPopoverShown, arrowEdge: .bottom) {
            PresetPopover(isPresented: $isPopoverShown)
        }
    }
}

