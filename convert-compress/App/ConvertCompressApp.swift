import SwiftUI

@main
struct ConvertCompressApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let modules: ImageToolsModules
    
    init() {
        let modules = ImageToolsModules()
        self.modules = modules
        appDelegate.openImageURLs = { [assets = modules.assets] urls in
            assets.addURLs(urls)
        }
    }
    
    var body: some Scene {
        Window(AppConstants.localizedAppName, id: "main") {
            MainView()
                .background(.clear)
                .imageToolsEnvironment(modules)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands()
        }
    }
}
