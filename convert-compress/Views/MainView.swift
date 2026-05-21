import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @Environment(AssetCollectionModule.self) private var assets
    @Bindable private var paywallCoordinator = PaywallCoordinator.shared
    @Bindable private var ratingCoordinator = RatingCoordinator.shared
    
    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ControlsBar()
            ContentArea()
            BottomBar()
        }
        .frame(minWidth: ControlLayout.mainWindowMinWidth)
        .background(.thickMaterial)
        .ignoresSafeArea(.all, edges: .top)
        .onAppear {
            WindowConfigurator.configureMainWindow()
            PurchaseManager.shared.configure()
        }
        .focusable()
        .focusEffectDisabled()
        .onCommand(#selector(NSText.paste(_:))) {
            assets.addFromPasteboard()
        }
        .sheet(isPresented: $paywallCoordinator.isPresented) {
            PaywallView()
        }
        .sheet(isPresented: $ratingCoordinator.isPresented) {
            RatingView()
        }
    }
}

#Preview {
    let modules = ImageToolsModules()
    MainView()
        .imageToolsEnvironment(modules)
}
