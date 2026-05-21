import SwiftUI

struct MetadataControl: View {
    @Environment(PipelineSettingsModule.self) private var settings
    
    var body: some View {
        @Bindable var settings = settings

        StrikePillToggle(isOn: $settings.removeMetadata) {
            Text(String(localized: "Metadata"))
        }
        .help(String(localized: settings.removeMetadata ? "Metadata will be removed" : "Preserve metadata"))
    }
} 
