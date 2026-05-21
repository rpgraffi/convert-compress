import SwiftUI
import AppKit

/// Orchestrates resize UI and delegates to specialized sub-controls.
struct ResizeControl: View {
    @Environment(PipelineSettingsModule.self) private var settings
    
    private var showsModeToggle: Bool {
        settings.allowedSquareSizes == nil
    }
    
    var body: some View {
        HStack(spacing: Layout.pillSpacing) {
            Group {
                if let sizes = settings.allowedSquareSizes {
                    SquaresResizeControl(allowedSizes: sizes.sorted())
                } else {
                    UnrestrictedResizeControl()
                }
            }
            .frame(minWidth: Layout.pillMinWidth, maxWidth: Theme.Metrics.controlMaxWidth)
            .help(String(localized: "Change image size"))
            
            
            if showsModeToggle {
                CircleIconButton(action: toggleMode) {
                    Image(systemName: settings.resizeMode == .resize ? "crop" : "arrow.down.forward.and.arrow.up.backward")
                        .font(.system(size: 11, weight: .medium))
                }
                .help(settings.resizeMode == .resize ? String(localized: "Switch to crop mode") : String(localized: "Switch to resize mode"))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(Theme.Animations.spring(), value: settings.resizeMode)
            }
        }
        .frame(height: Theme.Metrics.controlHeight)
        .frame(
            minWidth: ControlLayout.resizeControlMinWidth(includesModeToggle: showsModeToggle),
            maxWidth: ControlLayout.resizeControlMaxWidth(includesModeToggle: showsModeToggle)
        )
        .animation(Theme.Animations.spring(), value: settings.resizeMode)
    }
    
    private func toggleMode() {
        withAnimation(Theme.Animations.spring()) {
            if settings.resizeMode == .resize {
                settings.resizeMode = .crop
            } else {
                settings.resizeMode = .resize
            }
        }
    }
}

extension ResizeControl {
    enum Layout {
        static let pillSpacing: CGFloat = 4
        static let pillMinWidth: CGFloat = 168
    }
}
