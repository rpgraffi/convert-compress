import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    static var sharedViewModel: ImageToolsViewModel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.servicesProvider = self
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let vm = AppDelegate.sharedViewModel else { return }
        let expandedURLs = urls.flatMap { IngestionCoordinator.expandToSupportedImageURLs(from: $0) }
        vm.addURLs(expandedURLs)
    }
    
    @objc func handleFinderService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return
        }
        
        let expandedURLs = urls.flatMap { url -> [URL] in
            let standardized = url.standardizedFileURL
            SandboxAccessManager.shared.register(url: standardized)
            return IngestionCoordinator.expandToSupportedImageURLs(from: standardized)
        }

        self.application(NSApp, open: expandedURLs)
    }
}

@main
struct ConvertCompressApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let vm: ImageToolsViewModel
    
    init() {
        self.vm = ImageToolsViewModel()
        AppDelegate.sharedViewModel = vm
    }
    
    var body: some Scene {
        Window("Convert & Compress", id: "main") {
            MainView()
                .background(.clear)
        }
        .environmentObject(vm)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
