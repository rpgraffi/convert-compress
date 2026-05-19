import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct FormatControl: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    
    private let controlHeight: CGFloat = Theme.Metrics.controlHeight
    
    @State private var keyEventMonitor: LocalEventMonitor?
    
    private var pinnedFormats: [ImageFormat] {
        [ImageFormat(utType: .png), ImageFormat(utType: .jpeg), ImageFormat(utType: .heic), ImageFormat(utType: .webP)]
            .filter { ImageIOCapabilities.shared.supportsWriting(utType: $0.utType) }
    }
    
    private var otherFormats: [ImageFormat] {
        let pinnedIds = Set(pinnedFormats.map { $0.id })
        return ImageIOCapabilities.shared
            .writableFormats()
            .filter { !pinnedIds.contains($0.id) }
            .sorted { $0.displayName < $1.displayName }
    }
    
    private var selectedLabel: String {
        vm.selectedFormat?.displayName ?? String(localized: "Format")
    }
    
    private func shortcutFor(format: ImageFormat) -> Character? {
        switch format.utType {
        case .png: return "p"
        case .jpeg: return "j"
        case .heic: return "h"
        case .webP: return "w"
        default: return nil
        }
    }
    
    private func selectFormat(_ format: ImageFormat?) {
        vm.selectedFormat = format
        if let f = format { vm.bumpRecentFormats(f) }
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
            }
            .foregroundStyle(vm.selectedFormat != nil ? Color.accentColor : .primary)
        }
        .menuStyle(.borderlessButton)
        .help(vm.selectedFormat?.fullName ?? "")
        .frame(height: controlHeight)
        .padding(.horizontal, 8)
        .background(shape.fill(Theme.Colors.controlBackground))
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }

    // MARK: - Menu Builders

    @ViewBuilder
    private func recentSection() -> some View {
        let pinnedIds = Set(pinnedFormats.map { $0.id })
        let recents = vm.recentFormats.filter { !pinnedIds.contains($0.id) }.prefix(3)
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
        let vmDefault = ImageToolsViewModel()
        let vmPNG: ImageToolsViewModel = {
            let v = ImageToolsViewModel()
            v.selectedFormat = ImageFormat(utType: .png)
            return v
        }()
        let vmJPEG: ImageToolsViewModel = {
            let v = ImageToolsViewModel()
            v.selectedFormat = ImageFormat(utType: .jpeg)
            return v
        }()
        let vmWebP: ImageToolsViewModel = {
            let v = ImageToolsViewModel()
            v.selectedFormat = ImageFormat(utType: .webP)
            return v
        }()
        return VStack(alignment: .leading, spacing: 16) {
            FormatControl()
                .environmentObject(vmDefault)
            FormatControl()
                .environmentObject(vmPNG)
            FormatControl()
                .environmentObject(vmJPEG)
            FormatControl()
                .environmentObject(vmWebP)
        }
        .padding()
        .frame(width: 360)
    }
}
