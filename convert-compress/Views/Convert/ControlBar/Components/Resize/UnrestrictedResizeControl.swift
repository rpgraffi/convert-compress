import SwiftUI
import AppKit

struct UnrestrictedResizeControl: View {
    @Environment(PipelineSettingsModule.self) private var settings
    @Environment(AssetCollectionModule.self) private var assets
    
    var body: some View {
        @Bindable var settings = settings

        ZStack {
            if settings.resizeMode == .resize {
                ResizeSliderControl(
                    widthText: $settings.resizeWidth,
                    heightText: $settings.resizeHeight,
                    longEdgeText: $settings.resizeLongEdge,
                    baseSize: basePixelSizeForCurrentSelection(),
                    squareLocked: false
                )
                .transition(.opacity)
            } else {
                ResizeCropControl()
                    .transition(.opacity)
            }
        }
    }
    
    private func basePixelSizeForCurrentSelection() -> CGSize? {
        assets.basePixelSizeForCurrentSelection()
    }
}


