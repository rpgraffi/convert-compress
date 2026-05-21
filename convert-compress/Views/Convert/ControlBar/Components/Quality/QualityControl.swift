import SwiftUI
import AppKit

struct QualityControl: View {
    @Environment(PipelineSettingsModule.self) private var settings
    
    @FocusState private var kbFieldFocused: Bool
    
    var body: some View {
        @Bindable var settings = settings

        PercentPill(
            label: String(localized: "Quality"),
            value01: $settings.compressionPercent,
            dragStep: 0.05,
            showsTenPercentHaptics: true,
            showsFullBoundaryHaptic: true
        )
        .frame(minWidth: Theme.Metrics.controlMinWidth, maxWidth: Theme.Metrics.controlMaxWidth)
        .frame(height: Theme.Metrics.controlHeight)
        .help(String(localized: "Change image quality"))
    }
}
