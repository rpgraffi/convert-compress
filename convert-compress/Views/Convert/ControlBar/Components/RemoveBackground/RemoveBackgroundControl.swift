import SwiftUI

struct RemoveBackgroundControl: View {
    @Environment(PipelineSettingsModule.self) private var settings
    
    var body: some View {
        @Bindable var settings = settings

        CircleIconToggle(
            isOn: $settings.removeBackground,
            icon: Image(systemName: "person.and.background.dotted"),
            text: nil
        )
        .help(String(localized:"Remove background"))
    }
}


