import SwiftUI

/// Reusable preset item view that supports display and edit modes
struct PresetItemView<TrailingButtons: View>: View {
    let configuration: ProcessingConfiguration
    @Binding var name: String
    let isEditing: Bool
    let backgroundColor: Color
    let trailingButtons: () -> TrailingButtons
    
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void

    init(
        configuration: ProcessingConfiguration,
        name: Binding<String>,
        isEditing: Bool,
        backgroundColor: Color,
        @ViewBuilder trailingButtons: @escaping () -> TrailingButtons,
        isFocused: FocusState<Bool>.Binding,
        onSubmit: @escaping () -> Void
    ) {
        self.configuration = configuration
        self._name = name
        self.isEditing = isEditing
        self.backgroundColor = backgroundColor
        self.trailingButtons = trailingButtons
        self._isFocused = isFocused
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title or TextField
            if isEditing {
                TextField("Name", text: $name.maxLength(30))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit(onSubmit)
            } else {
                Text(name)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            
            // Configuration details
            configurationDetails
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(alignment: .trailing) {
            trailingButtons()
                .padding(.trailing, 8)
        }
    }
    
    private var configurationDetails: some View {
        HStack(spacing: 4) {
            // Format
            if let format = configuration.selectedFormat {
                Text(format.displayName)
                    .frame(minWidth: 40, alignment: .leading)
            }
            
            // Resizing
            resizeDetails
                .frame(minWidth: 70, alignment: .leading)
            
            // Quality
            if configuration.compressionPercent > 0 {
                HStack(spacing: 0) {
                    Text(String(format: "%.0f", configuration.compressionPercent * 100))
                    Text("%")
                }
                .frame(minWidth: 30, alignment: .leading)
            }
            
            // Mirror/Flip
            if configuration.flipV {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                .font(.system(size: 10))
            }
            
            // Remove Background
            if configuration.removeBackground {
                Image(systemName: "person.and.background.dotted")
                .font(.system(size: 10))
            }
            
            // Remove Metadata
            if configuration.removeMetadata {
                Image(systemName: "tag.slash.fill")
                .font(.system(size: 10))
            }
        }
        .monospacedDigit()
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
    
    @ViewBuilder
    private var resizeDetails: some View {
        let hasWidth = !configuration.resizeWidth.isEmpty
        let hasHeight = !configuration.resizeHeight.isEmpty
        let hasLongEdge = !configuration.resizeLongEdge.isEmpty
        
        if configuration.resizeMode == .crop && hasWidth && hasHeight {
            // Crop mode with both dimensions
            Text("\(configuration.resizeWidth)×\(configuration.resizeHeight)")
        } else if hasLongEdge {
            // Long edge mode
            HStack(spacing: 1) {
                Text(configuration.resizeLongEdge)
                Text("LE")
                    .opacity(0.6)
            }
        } else if hasWidth {
            // Width only
            HStack(spacing: 1) {
                Text(configuration.resizeWidth)
                Text("W")
                    .opacity(0.6)
            }
        } else if hasHeight {
            // Height only
            HStack(spacing: 1) {
                Text(configuration.resizeHeight)
                Text("H")
                    .opacity(0.6)
            }
        } else {
            // No resizing
            Text("Original")
        }
    }
}

