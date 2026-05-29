import SwiftUI
import AppKit

// MARK: Main View
struct ImageItem: View {
    let asset: ImageAsset
    @Environment(EncodedOutputModule.self) private var encodedOutput
    @Environment(ComparisonSessionModule.self) private var comparison
    @Environment(ImageToolsSessionModule.self) private var session
    let heroNamespace: Namespace.ID
    
    @State private var isHovering: Bool = false
    @State private var keyEventMonitor: LocalEventMonitor?
    
    private var fileName: String {
        asset.originalURL.lastPathComponent
    }
    
    var body: some View {
        let displayInfo = encodedOutput.displayInfo(for: asset)

        ZStack {
            thumbnailLayer
            fileNameOverlay
            hoverControlsOverlay
            infoOverlay(displayInfo: displayInfo)
        }
        .contentShape(Rectangle())
        .onHover(perform: handleHover)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .overlay { hoverBorder }
        .onDisappear { removeKeyMonitor() }
    }

    // MARK: View Components

    private var isActiveComparison: Bool {
        comparison.comparisonSelection?.assetID == asset.id
    }
    
    /// Only the currently-compared grid item (or all items when no comparison is active)
    /// should participate in the hero geometry group. Other items use `properties: []`
    /// so they don't produce stale matches during rapid navigation.
    private var heroProperties: MatchedGeometryProperties {
        comparison.comparisonSelection == nil || isActiveComparison ? .frame : []
    }
    
    @ViewBuilder
    private var thumbnailLayer: some View {
        ZStack {
            if let thumb = asset.thumbnail {
                ImageThumbnail(thumbnail: thumb)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.quaternary)
            }
        }
        .matchedGeometryEffect(
            id: "hero-\(asset.id)",
            in: heroNamespace,
            properties: heroProperties,
        )
        .opacity(isActiveComparison ? 0 : 1)
    }
    
    private var fileNameOverlay: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            SingleLineOverlayBadge(text: fileName)
                .matchedGeometryEffect(
                    id: "filename-\(asset.id)",
                    in: heroNamespace,
                    properties: heroProperties,
                )
                .padding(8)
        }
    }
    
    private var hoverControlsOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
            HoverControls(asset: asset, isVisible: isHovering)
        }
    }
    
    private func infoOverlay(displayInfo: ImageAssetDisplayInfo) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
            InfoOverlay(displayInfo: displayInfo)
        }
    }
    
    private var hoverBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .inset(by: isHovering ? -2 : 0)
            .stroke(Color.secondary, lineWidth: 1.5)
            .opacity(isHovering ? 0.6 : 0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
    
    private func handleHover(_ hovering: Bool) {
        isHovering = hovering
        if hovering {
            installKeyMonitor()
        } else {
            removeKeyMonitor()
        }
    }

    // MARK: Keyboard Handling

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyEventMonitor = LocalEventMonitor(mask: .keyDown) { [comparison, session, asset] event in
            // Spacebar
            if event.keyCode == 49 {
                comparison.presentComparison(for: asset)
                return nil
            }
            // X key
            if event.keyCode == 7 { 
                session.remove(asset)
                return nil
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
