import SwiftUI
import AppKit

struct QualityControl: View {
    @Environment(PipelineSettingsModule.self) private var settings
    
    var body: some View {
        @Bindable var settings = settings

        HStack(spacing: ResizeControl.Layout.pillSpacing) {
            ZStack {
                if settings.usesMaxFileSize {
                    MaxFileSizePill(kilobytes: $settings.maxFileSizeKB)
                        .help(String(localized: "Largest file size per image"))
                        .transition(.opacity)
                } else {
                    PercentPill(
                        label: String(localized: "Quality"),
                        value01: $settings.compressionPercent,
                        dragStep: 0.05,
                        showsTenPercentHaptics: true,
                        showsFullBoundaryHaptic: true
                    )
                    .help(String(localized: "Change image quality"))
                    .transition(.opacity)
                }
            }
            .flexibleWidth(min: Theme.Metrics.controlMinWidth, max: Theme.Metrics.controlMaxWidth)

            CircleIconButton(action: toggleMode) {
                Image(systemName: settings.usesMaxFileSize ? "percent" : "gauge.with.dots.needle.33percent")
                    .font(.system(size: 11, weight: .medium))
            }
            .help(settings.usesMaxFileSize ? String(localized: "Switch to quality") : String(localized: "Switch to max file size"))
        }
        .frame(height: Theme.Metrics.controlHeight)
    }

    private func toggleMode() {
        withAnimation(Theme.Animations.spring()) {
            settings.usesMaxFileSize.toggle()
        }
    }
}
