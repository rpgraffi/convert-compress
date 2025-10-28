import Foundation
import SwiftUI

@MainActor
@Observable
final class PaywallCoordinator {
    static let shared = PaywallCoordinator()
    
    // MARK: - State
    var isPresented = false
    private var onGrantAction: (() -> Void)?
    
    
    // MARK: - Public Methods
    func requestAccess(onGrant: @escaping () -> Void) {
        if PurchaseManager.shared.isProUnlocked {
            onGrant()
            return
        }
        
        onGrantAction = onGrant
        isPresented = true
    }
    
    func dismiss(executeAction: Bool = true) {
        if executeAction {
            onGrantAction?()
        }
        onGrantAction = nil
        isPresented = false
    }
    
    func presentManually() {
        onGrantAction = nil
        isPresented = true
    }
}

