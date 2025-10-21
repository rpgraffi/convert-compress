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
        
        Task { @MainActor in
            guard let vm = AppDelegate.sharedViewModel else { return }
            vm.addURLs(expandedURLs)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@main
struct ImageToolsApp: App {
    @StateObject private var vm = ImageToolsViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .background(.clear)
                .onAppear { AppDelegate.sharedViewModel = vm }
                .handlesExternalEvents(preferring: ["main"], allowing: ["*"])
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .environmentObject(vm)
        .handlesExternalEvents(matching: ["main"])
    }
}
