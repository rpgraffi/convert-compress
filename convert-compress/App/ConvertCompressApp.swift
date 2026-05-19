import SwiftUI

@main
struct ConvertCompressApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let vm: ImageToolsViewModel
    
    init() {
        self.vm = ImageToolsViewModel()
        appDelegate.openImageURLs = { [vm] urls in
            vm.addURLs(urls)
        }
    }
    
    var body: some Scene {
        Window(AppConstants.localizedAppName, id: "main") {
            MainView()
                .background(.clear)
        }
        .environmentObject(vm)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands()
        }
    }
}
