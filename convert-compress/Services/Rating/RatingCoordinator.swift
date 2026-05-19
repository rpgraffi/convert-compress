import Foundation
import SwiftUI
import StoreKit

@MainActor
@Observable
final class RatingCoordinator {
    static let shared = RatingCoordinator()
    
    var isPresented = false
    var showSecondPrompt = false
    
    private static let hasShownKey = StorageKeys.Rating.hasShown
    private static let declinedKey = StorageKeys.Rating.declined
    
    private init() {}
    
    func checkAndShowIfNeeded() {
        guard !hasShown, !declined, UsageTracker.shared.totalImageConversions >= 50 else { return }
        showSecondPrompt = false
        isPresented = true
    }
    
    func userLikesApp() {
        showSecondPrompt = true
    }
    
    func dismiss(permanently: Bool = false) {
        if permanently { declined = true }
        hasShown = true
        isPresented = false
        showSecondPrompt = false
    }
    
    func rateApp() {
        SKStoreReviewController.requestReview()
        dismiss()
    }
    
    private var hasShown: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasShownKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasShownKey) }
    }
    
    private var declined: Bool {
        get { UserDefaults.standard.bool(forKey: Self.declinedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.declinedKey) }
    }
}
