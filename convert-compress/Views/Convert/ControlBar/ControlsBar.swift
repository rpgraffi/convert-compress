import SwiftUI

struct ControlsBar: View {
    @Environment(PipelineSettingsModule.self) private var settings
    
    var body: some View {
        HStack(spacing: Layout.spacing) {
            PresetButton()
            FormatControl()
            ResizeControl()
            
            if settings.shouldShowCompressionControl {
                QualityControl()
                    .transition(.opacity.combined(with: .scale))
            }
            
            FlipControl()
            RemoveBackgroundControl()
            
            if settings.shouldShowMetadataControl {
                MetadataControl()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(Theme.Animations.spring(), value: settings.selectedFormat)
        .animation(Theme.Animations.spring(), value: settings.resizeMode)
        .animation(Theme.Animations.spring(), value: settings.removeMetadata)
        .animation(Theme.Animations.spring(), value: settings.allowedSquareSizes)
        .animation(Theme.Animations.spring(), value: settings.shouldShowCompressionControl)
        .animation(Theme.Animations.spring(), value: settings.shouldShowMetadataControl)
        .padding(.bottom, 4)
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

extension ControlsBar {
    enum Layout {
        static let spacing: CGFloat = 16
        static let horizontalPadding: CGFloat = 8
    }
}

