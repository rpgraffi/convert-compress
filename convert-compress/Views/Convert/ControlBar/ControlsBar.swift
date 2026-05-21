import SwiftUI

struct ControlsBar: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            PresetButton()
            FormatControl()
            ResizeControl()
            
            if vm.shouldShowCompressionControl {
                QualityControl()
                    .transition(.opacity.combined(with: .scale))
            }
            
            FlipControl()
            RemoveBackgroundControl()
            
            if vm.shouldShowMetadataControl {
                MetadataControl()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(Theme.Animations.spring(), value: vm.selectedFormat)
        .animation(Theme.Animations.spring(), value: vm.resizeMode)
        .animation(Theme.Animations.spring(), value: vm.overwriteOriginals)
        .animation(Theme.Animations.spring(), value: vm.removeMetadata)
        .animation(Theme.Animations.spring(), value: vm.allowedSquareSizes)
        .animation(Theme.Animations.spring(), value: vm.shouldShowCompressionControl)
        .animation(Theme.Animations.spring(), value: vm.shouldShowMetadataControl)
        .padding(.bottom, 4)
        .padding(.horizontal, 8)
    }
}

