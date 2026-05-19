import SwiftUI

struct ClearControl: View {
    @EnvironmentObject private var vm: ImageToolsViewModel

    private var mode: ClearControlMode {
        ClearControlMode(viewModel: vm)
    }

    var body: some View {
        PillButton(role: .destructive) {
            mode.perform(on: vm)
        } label: {
            Text(mode.label)
            .contentTransition(.interpolate)
        }
        .help(mode.helpText)
        .disabled(mode.requiresImages && vm.images.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: mode)
    }
}

private enum ClearControlMode: Equatable {
    case stopExport
    case clearExported
    case clearAll

    @MainActor
    init(viewModel: ImageToolsViewModel) {
        if viewModel.isExporting {
            self = .stopExport
        } else if viewModel.hasExportedAndNewImages {
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
    func perform(on viewModel: ImageToolsViewModel) {
        switch self {
        case .stopExport:
            viewModel.cancelExport()
        case .clearExported:
            viewModel.clearExported()
        case .clearAll:
            viewModel.clearAll()
        }
    }
}
