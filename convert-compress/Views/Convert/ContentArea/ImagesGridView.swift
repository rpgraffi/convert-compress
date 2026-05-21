import SwiftUI
import AppKit

struct ImagesGridView: View {
    @Environment(EncodedOutputModule.self) private var encodedOutput
    @Environment(ComparisonSessionModule.self) private var comparison
    let images: [ImageAsset]
    let columns: [GridItem]
    let heroNamespace: Namespace.ID
    @State private var visibleIds: Set<UUID> = []
    @State private var visibilityDebouncer = Debouncer()
    @State private var appearedIds: Set<UUID> = []

    private func scheduleVisibilityUpdate() {
        visibilityDebouncer.schedule(after: .milliseconds(150)) { [visibleIds] in
            encodedOutput.updateVisibleAssets(visibleIds)
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(images) { asset in
                    ImageItem(
                        asset: asset,
                        heroNamespace: heroNamespace
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .opacity(appearedIds.contains(asset.id) ? 1 : 0)
                    .scaleEffect(appearedIds.contains(asset.id) ? 1 : 0.94)
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: appearedIds.contains(asset.id))
                    .onTapGesture { 
                        comparison.presentComparison(for: asset)
                    }
                    .onAppear {
                        visibleIds.insert(asset.id)
                        scheduleVisibilityUpdate()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                            appearedIds.insert(asset.id)
                        }
                    }
                    .onDisappear { visibleIds.remove(asset.id); scheduleVisibilityUpdate() }
                }
            }
            .padding(10)
        }
        .scrollContentBackground(.hidden)
    }
}

struct ImagesGridView_Previews: PreviewProvider {
    static var previews: some View {
        let modules = ImageToolsModules()
        let urls: [URL] = [
            makeTempImageURL(size: NSSize(width: 640, height: 360), color: .systemBlue),
            makeTempImageURL(size: NSSize(width: 800, height: 800), color: .systemGreen),
            makeTempImageURL(size: NSSize(width: 600, height: 1200), color: .systemOrange)
        ]
        let assets = urls.map { ImageAsset(url: $0) }
        let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 12, alignment: .top)]
        
        return PreviewWrapper(assets: assets, columns: columns, modules: modules)
    }
    
    private struct PreviewWrapper: View {
        let assets: [ImageAsset]
        let columns: [GridItem]
        let modules: ImageToolsModules
        @Namespace private var heroNamespace
        
        var body: some View {
            ImagesGridView(images: assets, columns: columns, heroNamespace: heroNamespace)
                .imageToolsEnvironment(modules)
                .frame(width: 900, height: 600)
                .padding()
        }
    }
    
    private static func makeTempImageURL(size: NSSize, color: NSColor) -> URL {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        // Uses system /tmp which macOS cleans automatically
        let systemTmp = URL(fileURLWithPath: "/tmp")
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            return systemTmp.appendingPathComponent("preview_\(UUID().uuidString).png")
        }
        let url = systemTmp.appendingPathComponent("preview_\(UUID().uuidString).png")
        try? data.write(to: url)
        return url
    }
} 
