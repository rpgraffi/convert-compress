import SwiftUI

struct ControlsBar: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            PresetButton()
            FormatControl()
            ResizeControl()
            
            if shouldShowCompression {
                QualityControl()
                    .transition(.opacity.combined(with: .scale))
            }
            
            FlipControl()
            RemoveBackgroundControl()
            
            if shouldShowMetadata {
                MetadataControl()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(Theme.Animations.spring(), value: vm.selectedFormat)
        .animation(Theme.Animations.spring(), value: vm.resizeMode)
        .animation(Theme.Animations.spring(), value: vm.overwriteOriginals)
        .animation(Theme.Animations.spring(), value: vm.removeMetadata)
        .animation(Theme.Animations.spring(), value: vm.allowedSquareSizes)
        .animation(Theme.Animations.spring(), value: shouldShowCompression)
        .animation(Theme.Animations.spring(), value: shouldShowMetadata)
        .padding(.bottom, 4)
        .padding(.horizontal, 8)
    }
    
    private var shouldShowCompression: Bool {
        if let f = vm.selectedFormat {
            return ImageIOCapabilities.shared.capabilities(for: f).supportsQuality
        }
        return true
    }
    
    private var shouldShowMetadata: Bool {
        if let f = vm.selectedFormat {
            return ImageIOCapabilities.shared.capabilities(for: f).supportsMetadata
        }
        return true
    }
    
}

