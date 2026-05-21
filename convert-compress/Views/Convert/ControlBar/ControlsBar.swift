import SwiftUI

struct ControlsBar: View {
    @Environment(PipelineSettingsModule.self) private var settings
    
    var body: some View {
        HStack(spacing: 16) {
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
        .padding(.horizontal, 8)
    }
}

