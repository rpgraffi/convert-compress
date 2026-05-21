import SwiftUI

struct SaveControl: View {
    @Environment(AssetCollectionModule.self) private var assets
    @Environment(ExportSessionModule.self) private var export
    @State private var showDoneText: Bool = false
    
    var body: some View {
        let controlState = SaveControlState(
            assets: assets,
            export: export,
            showDoneText: showDoneText
        )
        let isInProgress = export.isExporting
        let height: CGFloat = 40
        let progressWidth: CGFloat = 200
        
        Button(role: .none) {
            guard controlState.allowsAction else { return }
            export.applyPipelineAsync()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: controlState.iconName)
                    .contentTransition(.symbolEffect(.replace))
                Text(controlState.label)
                    .contentTransition(controlState.isCounting ? .numericText() : .opacity)
                    .transition(.opacity)
                    .monospacedDigit()
            }
            .font(Theme.Fonts.button)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 20)
            .frame(width: controlState.usesProgressWidth ? progressWidth : nil, height: height)
            .frame(minWidth: height)
            .background {
                ZStack(alignment: .leading) {
                    // Background
                    Color.secondary.opacity(0.2)
                    
                    if !controlState.isDisabled {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: controlState.displayedProgress * proxy.size.width)
                                .animation(Theme.Animations.spring(), value: controlState.displayedProgress)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: .infinity, style: .continuous))
            .contentShape(Rectangle())
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.plain)
        .shadow(color: Color.accentColor.opacity(controlState.showsShadow ? 0.25 : 0), radius: 8, x: 0, y: 2)
        .disabled(controlState.isDisabled || controlState.isIngesting)
        .allowsHitTesting(controlState.allowsAction)
        .help(String(localized: "Save images"))
        .onChange(of: isInProgress) { _, isNowInProgress in
            if !isNowInProgress {
                // Show "Done" briefly when progress finishes
                withAnimation(Theme.Animations.spring()) {
                    showDoneText = true
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                    withAnimation(Theme.Animations.spring()) {
                        showDoneText = false
                    }
                }
            } else {
                // Reset immediately when starting again
                showDoneText = false
            }
        }
        .animation(Theme.Animations.spring(), value: isInProgress)
        .animation(Theme.Animations.spring(), value: showDoneText)
        .animation(Theme.Animations.spring(), value: controlState)
    }
}

private enum SaveControlState: Equatable {
    case disabled
    case idle
    case ingesting(text: String, progress: Double)
    case exporting(text: String, progress: Double)
    case done

    @MainActor
    init(
        assets: AssetCollectionModule,
        export: ExportSessionModule,
        showDoneText: Bool
    ) {
        if let ingestText = assets.ingestCounterText {
            self = .ingesting(text: ingestText, progress: assets.ingestFraction)
        } else if export.isExporting {
            let text = "\(export.exportCompleted)/\(export.exportTotal)"
            self = .exporting(text: text, progress: export.exportFraction)
        } else if assets.images.isEmpty {
            self = .disabled
        } else if showDoneText {
            self = .done
        } else {
            self = .idle
        }
    }

    var label: String {
        switch self {
        case .disabled, .idle:
            String(localized: "Save")
        case .ingesting(let text, _), .exporting(let text, _):
            text
        case .done:
            String(localized: "Done")
        }
    }

    var iconName: String {
        switch self {
        case .disabled, .idle:
            "photo.stack.fill"
        case .ingesting:
            "arrow.down.app.dashed"
        case .exporting:
            "hourglass"
        case .done:
            "checkmark.rectangle.stack.fill"
        }
    }

    var displayedProgress: Double {
        switch self {
        case .ingesting(_, let progress), .exporting(_, let progress):
            max(min(progress, 1.0), 0.0)
        case .disabled:
            0
        case .idle, .done:
            1
        }
    }

    var isCounting: Bool {
        switch self {
        case .ingesting, .exporting:
            true
        case .disabled, .idle, .done:
            false
        }
    }

    var usesProgressWidth: Bool {
        isCounting
    }

    var isDisabled: Bool {
        self == .disabled
    }

    var isIngesting: Bool {
        if case .ingesting = self { return true }
        return false
    }

    var allowsAction: Bool {
        switch self {
        case .idle, .done:
            true
        case .disabled, .ingesting, .exporting:
            false
        }
    }

    var showsShadow: Bool {
        switch self {
        case .idle, .done:
            true
        case .disabled, .ingesting, .exporting:
            false
        }
    }
}


#Preview("SaveControl") {
    struct Demo: View {
        @State private var disabled = false
        @State private var inProgress = false
        @State private var progress: Double = 0.0
        @State private var count: Int? = nil
        
        var body: some View {
            VStack(spacing: 20) {
                SaveControl()
                
                HStack {
                    Toggle("Disabled", isOn: $disabled)
                    Toggle("In Progress", isOn: $inProgress)
                }
                .toggleStyle(.switch)
                
                HStack(spacing: 12) {
                    Text("Progress")
                    Slider(value: $progress, in: 0...1)
                        .disabled(!inProgress)
                }
                
                HStack(spacing: 12) {
                    Text("Counter")
                    Stepper(value: Binding(get: { count ?? 0 }, set: { count = $0 }), in: 0...10_000) {
                        Text(count.map(String.init) ?? "nil")
                    }
                }
            }
            .padding()
            .frame(width: 400)
        }
    }
    return Demo()
}
