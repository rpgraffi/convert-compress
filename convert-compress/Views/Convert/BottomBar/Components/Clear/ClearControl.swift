import SwiftUI

struct ClearControl: View {
    @Environment(AssetCollectionModule.self) private var assets
    @Environment(ExportSessionModule.self) private var export
    @Environment(ImageToolsSessionModule.self) private var session

    private var mode: ClearControlMode {
        ClearControlMode(assets: assets, export: export)
    }

    var body: some View {
        PillButton(role: .destructive) {
            mode.perform(session: session)
        } label: {
            Text(mode.label)
            .contentTransition(.interpolate)
        }
        .help(mode.helpText)
        .disabled(mode.requiresImages && assets.images.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: mode)
    }
}

private enum ClearControlMode: Equatable {
    case stopExport
    case clearExported
    case clearAll

    @MainActor
    init(assets: AssetCollectionModule, export: ExportSessionModule) {
        if export.isExporting {
            self = .stopExport
        } else if assets.hasExportedAndNewImages {
            self = .clearExported
        } else {
            self = .clearAll
        }
    }

    var label: String {
        switch self {
        case .stopExport:
            String(localized: "Stop")
        case .clearExported:
            String(localized: "Clear old")
        case .clearAll:
            String(localized: "Clear")
        }
    }

    var helpText: String {
        switch self {
        case .stopExport:
            String(localized: "Stop exporting")
        case .clearExported:
            String(localized: "Clear exported images")
        case .clearAll:
            String(localized: "Clear all images")
        }
    }

    var requiresImages: Bool {
        self != .stopExport
    }

    @MainActor
    func perform(session: ImageToolsSessionModule) {
        switch self {
        case .stopExport:
            session.stopExport()
        case .clearExported:
            session.clearExported()
        case .clearAll:
            session.clearAll()
        }
    }
}
