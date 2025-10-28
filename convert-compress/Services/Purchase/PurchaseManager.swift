import Foundation
import StoreKit

@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()
    
    // MARK: - Properties
    
    private(set) var isPurchasing = false
    private(set) var isProUnlocked = false
    var purchaseError: String?
    var lifetimeDisplayPrice: String?
    var lifetimeRegularDisplayPrice: String?
    
    // MARK: - Private Properties
    
    private var lifetimeProduct: Product?
    private var lifetimeRegularProduct: Product?
    private var transactionUpdateTask: Task<Void, Never>?
    
    private let lifetimeProductId = "lifetime"
    private let lifetimeRegularProductId = "lifetime_regular"
    private var proEntitlementProductIds: Set<String> {
        [lifetimeProductId, lifetimeRegularProductId]
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure() {
        guard transactionUpdateTask == nil else { return }
        
        transactionUpdateTask = Task {
            await observeTransactions()
        }
        
        Task {
            await checkEntitlements()
            await loadProducts()
        }
    }
    
    // MARK: - Products
    
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [lifetimeProductId, lifetimeRegularProductId])
            
            lifetimeProduct = products.first(where: { $0.id == lifetimeProductId })
            lifetimeRegularProduct = products.first(where: { $0.id == lifetimeRegularProductId })
            
            lifetimeDisplayPrice = lifetimeProduct?.displayPrice
            lifetimeRegularDisplayPrice = lifetimeRegularProduct?.displayPrice
            
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    // MARK: - Entitlements
    
    func checkEntitlements() async {
        var hasEntitlement = false
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if proEntitlementProductIds.contains(transaction.productID) {
                hasEntitlement = true
                break
            }
        }
        
        isProUnlocked = hasEntitlement
        
    }
    
    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if proEntitlementProductIds.contains(transaction.productID) {
                isProUnlocked = true
                await transaction.finish()
            }
        }
    }
    
    // MARK: - Purchase
    
    func purchaseLifetime() async {
        guard !isPurchasing else { return }
        
        // Load products if needed
        if lifetimeProduct == nil && lifetimeRegularProduct == nil {
            await loadProducts()
        }
        
        guard let product = lifetimeProduct ?? lifetimeRegularProduct else {
            purchaseError = "Product not available. Please try again."
            return
        }
        
        isPurchasing = true
        purchaseError = nil
        
        defer { isPurchasing = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "Purchase verification failed."
                    return
                }
                
                if proEntitlementProductIds.contains(transaction.productID) {
                    isProUnlocked = true
                }
                
                await transaction.finish()
                
            case .userCancelled:
                print("User cancelled purchase")
            case .pending:
                print("Purchase Pending")
            @unknown default:
                break
            }
        } catch {
            print("Purchase failed: \(error)")
            purchaseError = "Purchase failed. Please try again."
        }
    }
    
    // MARK: - Restore
    
    func restorePurchases() async {
        guard !isPurchasing else { return }
        
        isPurchasing = true
        purchaseError = nil
        
        defer { isPurchasing = false }
        
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            print("Restore failed: \(error)")
            purchaseError = "Restore failed. Please try again."
        }
    }
}
