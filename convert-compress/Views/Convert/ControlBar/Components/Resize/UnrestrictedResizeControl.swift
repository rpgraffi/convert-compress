import SwiftUI
import AppKit

struct UnrestrictedResizeControl: View {
    @Environment(PipelineSettingsModule.self) private var settings
    @Environment(AssetCollectionModule.self) private var assets
    
    var body: some View {
        @Bindable var settings = settings

        ZStack {
            GeometryReader { geo in
                let size = geo.size
                Group {
                    if settings.resizeMode == .resize {
                        ResizeSliderControl(
                            widthText: $settings.resizeWidth,
                            heightText: $settings.resizeHeight,
                            longEdgeText: $settings.resizeLongEdge,
                            baseSize: basePixelSizeForCurrentSelection(),
                            containerSize: size,
                            squareLocked: false
                        )
                        .transition(.opacity)
                    } else {
                        ResizeCropControl()
                            .transition(.opacity)
                    }
                }
            }
            .frame(minWidth: ResizeControl.Layout.pillMinWidth)
        }
    }
    
    private func basePixelSizeForCurrentSelection() -> CGSize? {
        assets.basePixelSizeForCurrentSelection()
    }
}


