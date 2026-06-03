import SwiftUI

struct RenameControl: View {
    @Environment(ExportRenameModule.self) private var rename

    var body: some View {
        CircleIconToggle(
            isOn: Binding(
                get: { rename.isEnabled },
                set: { rename.setEnabled($0) }
            ),
            icon: Image(systemName: "textformat")
        )
        .help(String(localized: rename.isEnabled ? "Disable renaming" : "Rename exported files"))
        .popover(
            isPresented: Binding(
                get: { rename.isPopoverPresented },
                set: { rename.setPopoverPresented($0) }
            ),
            arrowEdge: .bottom
        ) {
            RenamePopover()
        }
    }
}

