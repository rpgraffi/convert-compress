import SwiftUI

struct HoverIconButton: View {
    let systemName: String
    let action: () -> Void
    var tint: Color = .secondary
    var hoverTint: Color = .primary
    var size: CGFloat = 32
    var iconSize: CGFloat = 12
    var iconWeight: Font.Weight = .medium
    var cornerRadius: CGFloat = 8
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: iconWeight))
                .foregroundStyle(isHovering ? hoverTint : tint)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isHovering ? Color.secondary.opacity(0.12) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.07)) {
                isHovering = hovering
            }
        }
    }
}

// Convenience initializer for destructive actions
extension HoverIconButton {
    init(
        systemName: String,
        action: @escaping () -> Void,
        destructive: Bool,
        size: CGFloat = 32,
        iconSize: CGFloat = 12,
        iconWeight: Font.Weight = .medium,
        cornerRadius: CGFloat = 8
    ) {
        self.systemName = systemName
        self.action = action
        self.tint = destructive ? .red.opacity(0.7) : .secondary
        self.hoverTint = destructive ? .red : .primary
        self.size = size
        self.iconSize = iconSize
        self.iconWeight = iconWeight
        self.cornerRadius = cornerRadius
    }
}

