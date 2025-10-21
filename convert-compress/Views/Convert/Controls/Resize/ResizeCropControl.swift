import SwiftUI
import AppKit

struct ResizeCropView: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    
    var body: some View {
        HStack(spacing: 2) {
            // Width field
            InputPillField(
                label: "W",
                text: $vm.resizeWidth,
                cornerRadius: .infinity
            )
            .onChange(of: vm.resizeWidth) { _, newValue in
                parseDimensionsIfNeeded(from: newValue)
            }
            
            // Height field
            InputPillField(
                label: "H",
                text: $vm.resizeHeight,
                cornerRadius: .infinity
            )
            .onChange(of: vm.resizeHeight) { _, newValue in
                parseDimensionsIfNeeded(from: newValue)
            }
        }
        .frame(height: Theme.Metrics.controlHeight)
        .cornerRadius(.infinity)
    }
    
    /// Parses dimension strings like "680x340", "680 x 340", "680X340", "680 340", "680/340", etc.
    /// If a valid pattern is found, automatically populates both width and height fields.
    private func parseDimensionsIfNeeded(from text: String) {
        guard let dimensions = parseDimensions(from: text) else {
            return
        }
        
        vm.resizeWidth = dimensions.width
        vm.resizeHeight = dimensions.height
    }
}

struct InputPillField: View {
    let label: String
    @Binding var text: String
    let cornerRadius: CGFloat
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(Theme.Fonts.button)
                .foregroundColor(text.isEmpty ? .secondary : .primary)
                .padding(.leading, 10)
            
            Spacer()
            
            TextField("px", text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .font(Theme.Fonts.button)
                .monospacedDigit()
                .tint(Color.primary)
                .onSubmit {
                    isFocused = false
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
                .frame(alignment: .trailing)
                .padding(.trailing, 10)
        }
        .frame(height: Theme.Metrics.controlHeight)
        .background(text.isEmpty ? Theme.Colors.controlBackground : Color.accentColor)
        .cornerRadius(4)
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
        .onTapGesture {
            isFocused = true
        }
    }
}
