import SwiftUI

struct RenameControl: View {
    @Environment(ExportSessionModule.self) private var export
    @State private var isPopoverShown = false

    var body: some View {
        @Bindable var export = export

        CircleIconToggle(
            isOn: $export.isRenameEnabled,
            icon: Image(systemName: "textformat")
        )
        .help(String(localized: export.isRenameEnabled ? "Disable renaming" : "Rename exported files"))
        .popover(isPresented: $isPopoverShown, arrowEdge: .bottom) {
            RenamePopover(isPresented: $isPopoverShown)
        }
        .onChange(of: export.isRenameEnabled) { _, isEnabled in
            isPopoverShown = isEnabled
        }
    }
}

