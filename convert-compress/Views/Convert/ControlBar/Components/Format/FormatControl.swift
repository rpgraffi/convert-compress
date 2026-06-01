import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct FormatControl: View {
    @Environment(PipelineSettingsModule.self) private var settings
    
    private let controlHeight: CGFloat = Theme.Metrics.controlHeight
    
    @State private var keyEventMonitor: LocalEventMonitor?
    
    private var pinnedFormats: [ImageFormat] {
        settings.pinnedWritableFormats
    }
    
    private var otherFormats: [ImageFormat] {
        settings.otherWritableFormats
    }
    
    private var selectedLabel: String {
        settings.selectedFormat?.displayName ?? String(localized: "Format")
    }
    
    private func shortcutFor(format: ImageFormat) -> Character? {
        switch format.utType {
        case .avif: return "a"
        case .png: return "p"
        case .jpeg: return "j"
        case .heic: return "h"
        case .webP: return "w"
        default: return nil
        }
    }
    
    private func selectFormat(_ format: ImageFormat?) {
        settings.selectFormat(format)
    }
    
    var body: some View {
        let shape = Capsule()
        
        Menu {
            
            recentSection()
            pinnedSection()
            Button(String(localized: "Original")) { selectFormat(nil) }
                .keyboardShortcut(.init("o"), modifiers: [])
            Divider()
            
            moreSection()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled.fill")
                    .font(Theme.Fonts.button)
                
                Text(selectedLabel)
                    .font(Theme.Fonts.button)
                    .fixedSize(horizontal: true, vertical: false)
                    .contentTransition(.opacity)
            }
            .foregroundStyle(settings.selectedFormat != nil ? Color.accentColor : .primary)
            .fixedSize(horizontal: true, vertical: false)
        }
        .menuStyle(.borderlessButton)
        .help(settings.selectedFormat?.fullName ?? "")
        .frame(height: controlHeight)
        .padding(.horizontal, 8)
        .background(shape.fill(Theme.Colors.controlBackground))
        .animation(Theme.Animations.spring(), value: settings.selectedFormat?.id)
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }

    // MARK: - Menu Builders

    @ViewBuilder
    private func recentSection() -> some View {
        let pinnedIds = Set(pinnedFormats.map { $0.id })
        let recents = settings.recentFormats.filter { !pinnedIds.contains($0.id) }.prefix(3)
        if !recents.isEmpty {
            Section(String(localized: "Recent")) {
                ForEach(Array(recents), id: \.id) { f in
                    Button(f.displayName) { selectFormat(f) }
                        .help(f.fullName)
                }
            }
        }
    }
    
    @ViewBuilder
    private func pinnedSection() -> some View {
        Section {
            ForEach(pinnedFormats, id: \.id) { f in
                pinnedRowButton(f)
            }
        }
    }
    
    @ViewBuilder
    private func moreSection() -> some View {
        if !otherFormats.isEmpty {
            Menu(String(localized: "More")) {
                ForEach(otherFormats, id: \.id) { f in
                    Button(f.displayName) { selectFormat(f) }
                        .help(f.fullName)
                }
            }
        }
    }
    
    @ViewBuilder
    private func pinnedRowButton(_ f: ImageFormat) -> some View {
        if let shortcut = shortcutFor(format: f) {
            Button(f.displayName) { selectFormat(f) }
                .keyboardShortcut(KeyEquivalent(shortcut), modifiers: [])
                .help(f.fullName)
        } else {
            Button(f.displayName) { selectFormat(f) }
                .help(f.fullName)
        }
    }

    // MARK: - Keyboard Handling

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyEventMonitor = LocalEventMonitor(mask: .keyDown) { event in
            if KeyWindowEditing.isTextInputFocused {
                return event
            }
            
            guard let chars = event.charactersIgnoringModifiers?.lowercased(), event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
                return event
            }
            switch chars {
            case "o":
                selectFormat(nil); return nil
            default:
                if let matchingFormat = pinnedFormats.first(where: { shortcutFor(format: $0).map(String.init) == chars }) {
                    selectFormat(matchingFormat)
                    return nil
                }
                break
            }
            return event
        }
        keyEventMonitor?.start()
    }
    
    private func removeKeyMonitor() {
        keyEventMonitor?.stop()
        keyEventMonitor = nil
    }
}

struct FormatControlView_Previews: PreviewProvider {
    static var previews: some View {
        let settingsDefault = PipelineSettingsModule()
        let settingsPNG: PipelineSettingsModule = {
            let v = PipelineSettingsModule()
            v.selectedFormat = ImageFormat(utType: .png)
            return v
        }()
        let settingsJPEG: PipelineSettingsModule = {
            let v = PipelineSettingsModule()
            v.selectedFormat = ImageFormat(utType: .jpeg)
            return v
        }()
        let settingsWebP: PipelineSettingsModule = {
            let v = PipelineSettingsModule()
            v.selectedFormat = ImageFormat(utType: .webP)
            return v
        }()
        let settingsAVIF: PipelineSettingsModule = {
            let v = PipelineSettingsModule()
            v.selectedFormat = ImageFormat(utType: .avif)
            return v
        }()
        return VStack(alignment: .leading, spacing: 16) {
            FormatControl()
                .environment(settingsDefault)
            FormatControl()
                .environment(settingsAVIF)
            FormatControl()
                .environment(settingsPNG)
            FormatControl()
                .environment(settingsJPEG)
            FormatControl()
                .environment(settingsWebP)
        }
        .padding()
        .frame(width: 360)
    }
}
