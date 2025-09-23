//
//  File name: SubscriptionManager.swift
//  Project name: apple-custom-subscription-view
//  Workspace name: apple-custom-subscription-view
//
//  Created by: nothing-to-add on 16/09/2025
//  Using Swift 6.0
//  Copyright (c) 2023 nothing-to-add
//

import Foundation
import StoreKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CustomToastManager
import CustomLogger

@MainActor
public class SubscriptionManager: ObservableObject {
    @Published public var isLoading = false
    @Published public var products: [Product] = []
    @Published public var purchaseState: PurchaseState = .notPurchased
    @Published public var isStoreKitAvailable = true
    
    // Reference to premium status manager for local status management
    weak var premiumStatusManager: PremiumStatusManager?
    
    public enum PurchaseState {
        case notPurchased, purchased, failed, pending
    }
    
    public enum SubscriptionError: LocalizedError {
        case noAppVersionInReview
        case storeKitUnavailable
        case productNotConfigured
        
        var errorDescription: LocalizedStringResource {
            switch self {
            case .noAppVersionInReview:
                return "Subscriptions require an app version in App Store review. Please submit your app for review first."
            case .storeKitUnavailable:
                return "In-app purchases are not available in development mode."
            case .productNotConfigured:
                return "Subscription products are not configured in App Store Connect."
            }
        }
    }
    
    public let productIds: [String]
    public let premiumFeatures: [PremiumFeature]
    public let trialPeriodDays: Int
    public let termsOfServiceURL: String
    public let privacyPolicyURL: String
    public let headerTitle: LocalizedStringResource
    public let headerSubtitle: LocalizedStringResource
    
    public init(productIds: [String], premiumFeatures: [PremiumFeature], trialPeriodDays: Int, termsOfServiceURL: String, privacyPolicyURL: String, headerTitle: LocalizedStringResource? = nil, headerSubtitle: LocalizedStringResource? = nil) {
        self.productIds = productIds
        self.premiumFeatures = premiumFeatures
        self.trialPeriodDays = trialPeriodDays
        self.termsOfServiceURL = termsOfServiceURL
        self.privacyPolicyURL = privacyPolicyURL
        self.headerTitle = headerTitle ?? LocalizedStringResource("Upgrade to Premium", bundle: .module)
        self.headerSubtitle = headerSubtitle ?? LocalizedStringResource("Unlock exclusive features", bundle: .module)
        
        // Check if StoreKit is available (not in development simulator without proper setup)
        checkStoreKitAvailability()
        
        // Start listening for transaction updates only if StoreKit is available
        if isStoreKitAvailable {
            Task {
                await listenForTransactions()
            }
        }
    }
    
    /// Check if StoreKit is properly configured and available
    private func checkStoreKitAvailability() {
        // In development, StoreKit might not be properly configured
        // This is a basic check - more sophisticated detection can be added
        #if DEBUG
        Logger.shared.debug("🔍 Checking StoreKit availability...", category: .subscription)
        #endif
        
        // For now, assume it's available unless we detect specific errors
        isStoreKitAvailable = true
    }
    
    /// Load available subscription products from App Store
    public func loadProducts() async {
        guard isStoreKitAvailable else {
            #if DEBUG
            Logger.shared.debug("⚠️ StoreKit not available - using mock products for development", category: .subscription)
            await createMockProducts()
            #endif
            return
        }
        
        do {
            let products = try await Product.products(for: productIds)
            
            if products.isEmpty {
                #if DEBUG
                Logger.shared.debug("⚠️ No products returned from App Store", category: .subscription)
                Logger.shared.debug("💡 This usually means:", category: .subscription)
                Logger.shared.debug("   1. Products not configured in App Store Connect", category: .subscription)
                Logger.shared.debug("   2. App not submitted for review yet", category: .subscription)
                Logger.shared.debug("   3. Bundle ID mismatch", category: .subscription)
                await createMockProducts()
                #else
                throw SubscriptionError.productNotConfigured
                #endif
                return
            }
            
            self.products = products.sorted { product1, product2 in
                // Sort: monthly first, then annual
                if product1.id.contains("monthly") { return true }
                if product2.id.contains("monthly") { return false }
                return product1.price < product2.price
            }
            
            #if DEBUG
            Logger.shared.debug("✅ Loaded \(products.count) subscription products", category: .subscription)
            for product in products {
                Logger.shared.debug("   - \(product.id): \(product.displayName) - \(product.displayPrice)", category: .subscription)
            }
            #endif
            
        } catch {
            Logger.shared.debug("Failed to load products: \(error)", category: .subscription)
            
            // Check for specific StoreKit errors
            if let storeKitError = error as? StoreKitError {
                switch storeKitError {
                case .notAvailableInStorefront:
                    isStoreKitAvailable = false
                    ToastManager.shared.showError("Subscriptions not available in your region")
                case .networkError:
                    ToastManager.shared.showError("Network error loading subscriptions")
                default:
                    if error.localizedDescription.contains("review") {
                        ToastManager.shared.showError(SubscriptionError.noAppVersionInReview.errorDescription)
                    } else {
                        ToastManager.shared.showError("Failed to load subscription options")
                    }
                }
            } else {
                ToastManager.shared.showError("Failed to load subscription options")
            }
            
            #if DEBUG
            // In debug mode, create mock products for UI testing
            await createMockProducts()
            #endif
        }
    }
    
    /// Create mock products for development testing
    #if DEBUG
    private func createMockProducts() async {
        // This is just for UI testing - won't actually work for purchases
        Logger.shared.debug("🧪 Creating mock products for development UI testing", category: .subscription)
        // Note: We can't create actual Product instances, but we can update the UI state
        // to show that products would be available
    }
    #endif
    
    /// Purchase a subscription product
    public func purchase(productId: String) async {
        guard isStoreKitAvailable else {
            #if DEBUG
            Logger.shared.debug("🧪 Mock purchase initiated for: \(productId)", category: .subscription)
            ToastManager.shared.showInfo("Purchase simulation (Development Mode)")
            // Simulate successful purchase in development
            premiumStatusManager?.updatePremiumStatus(true)
            purchaseState = .purchased
            #else
            ToastManager.shared.showError(SubscriptionError.storeKitUnavailable.errorDescription)
            #endif
            return
        }
        
        guard let product = products.first(where: { $0.id == productId }) else {
            ToastManager.shared.showError("Product not found")
            return
        }
        
        isLoading = true
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    // Handle successful purchase
                    await handleSuccessfulPurchase(transaction)
                    await transaction.finish()
                    purchaseState = .purchased
                    ToastManager.shared.showSuccess("Premium subscription activated!")
                } else {
                    // Handle unverified transaction
                    purchaseState = .failed
                    ToastManager.shared.showError("Purchase verification failed")
                }
            case .userCancelled:
                purchaseState = .notPurchased
                // User cancelled - no error message needed
            case .pending:
                purchaseState = .pending
                ToastManager.shared.showInfo("Purchase is pending approval")
            @unknown default:
                purchaseState = .failed
                ToastManager.shared.showError("Unknown purchase result")
            }
        } catch {
            Logger.shared.debug("Purchase failed: \(error)", category: .subscription)
            purchaseState = .failed
            
            // Handle specific errors
            if error.localizedDescription.contains("review") ||
               error.localizedDescription.contains("activate subscriptions independently") {
                ToastManager.shared.showError(SubscriptionError.noAppVersionInReview.errorDescription)
            } else {
                ToastManager.shared.showError("Purchase failed: \(error.localizedDescription)")
            }
        }
        
        isLoading = false
    }
    
    /// Restore previous purchases
    public func restorePurchases() async {
        guard isStoreKitAvailable else {
            #if DEBUG
            ToastManager.shared.showInfo("Restore simulation (Development Mode)")
            #else
            ToastManager.shared.showError(SubscriptionError.storeKitUnavailable.errorDescription)
            #endif
            return
        }
        
        isLoading = true
        
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            
            if premiumStatusManager?.isPremium == true {
                ToastManager.shared.showSuccess("Premium subscription restored!")
            } else {
                ToastManager.shared.showInfo("No previous purchases found")
            }
        } catch {
            Logger.shared.debug("Restore failed: \(error)", category: .subscription)
            
            if error.localizedDescription.contains("review") ||
               error.localizedDescription.contains("activate subscriptions independently") {
                ToastManager.shared.showError(SubscriptionError.noAppVersionInReview.errorDescription)
            } else {
                ToastManager.shared.showError("Failed to restore purchases")
            }
        }
        
        isLoading = false
    }
    
    /// Check current subscription status
    public func checkSubscriptionStatus() async {
        guard isStoreKitAvailable else {
            #if DEBUG
            Logger.shared.debug("🧪 Skipping subscription status check - StoreKit not available", category: .subscription)
            #endif
            return
        }
        
        var hasActiveSubscription = false
        
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIds.contains(transaction.productID) {
                    hasActiveSubscription = true
                    break
                }
            }
        }
        
        // Update premium status manager with the current subscription state
        // Since this class is @MainActor, we're already on the main thread
        premiumStatusManager?.updatePremiumStatus(hasActiveSubscription)
    }
    
    /// Listen for transaction updates
    private func listenForTransactions() async {
        for await result in StoreKit.Transaction.updates {
            if case .verified(let transaction) = result {
                await handleSuccessfulPurchase(transaction)
                await transaction.finish()
            }
        }
    }
    
    /// Handle a successful purchase transaction
    private func handleSuccessfulPurchase(_ transaction: StoreKit.Transaction) async {
        // Update premium status through the premium status manager
        premiumStatusManager?.updatePremiumStatus(true)
        
        Logger.shared.debug("✅ Successful purchase: \(transaction.productID)", category: .subscription)
    }
    
    /// Get formatted price for a product
    public func formattedPrice(for productId: String) -> String {
        guard let product = products.first(where: { $0.id == productId }) else {
            // Fallback to hardcoded prices if products not loaded
            if productId.contains("monthly") {
                return "$9.99"
            } else {
                return "$39.99"
            }
        }
        
        return product.displayPrice
    }
    
    /// Get formatted period for a product
    public func formattedPeriod(for productId: String) -> LocalizedStringResource {
        guard let product = products.first(where: { $0.id == productId }),
              let subscriptionInfo = product.subscription else {
            return "per period" // Fallback
        }
        
        let period = subscriptionInfo.subscriptionPeriod
        
        switch period.unit {
        case .day:
            return "per \(period.value) days"
        case .week:
            return "per \(period.value) weeks"
        case .month:
            return "per \(period.value) months"
        case .year:
            return "per \(period.value) years"
        @unknown default:
            return "per period"
        }
    }
    
    /// Get formatted title for a product
    public func formattedTitle(for productId: String) -> LocalizedStringResource {
        guard let product = products.first(where: { $0.id == productId }),
              let subscriptionInfo = product.subscription else {
            return "Periodically" // Fallback
        }
        
        let period = subscriptionInfo.subscriptionPeriod
        
        switch period.unit {
        case .day:
            return "Daily"
        case .week:
            return "Weekly"
        case .month:
            return "Monthly"
        case .year:
            return "Annual"
        @unknown default:
            return "Periodically"
        }
    }
    
    /// Calculate savings percentage compared to the most expensive option per unit time
    public func calculateSavings(for productId: String) -> LocalizedStringResource? {
        guard !products.isEmpty else { return nil }
        
        // Calculate cost per day for all products
        var productCosts: [(productId: String, costPerDay: Decimal)] = []
        
        for product in products {
            // Skip products without a subscription
            guard let costPerDay = getCostPerDay(for: product) else { continue }
            
            productCosts.append((productId: product.id, costPerDay: costPerDay))
        }
        
        guard let targetProduct = productCosts.first(where: { $0.productId == productId }),
              productCosts.count > 1 else { return nil }
        
        // Find the most expensive cost per day (baseline for comparison)
        let maxCostPerDay = productCosts.map { $0.costPerDay }.max() ?? 0
        
        // Calculate savings percentage
        let savingsAmount = maxCostPerDay - targetProduct.costPerDay
        let savingsPercentage = (savingsAmount / maxCostPerDay) * 100
        
        // Convert to Double for rounding
        let savingsPercentageDouble = NSDecimalNumber(decimal: savingsPercentage).doubleValue
        let roundedPercentage = Int(savingsPercentageDouble.rounded())
        
        return roundedPercentage > 0 ? "Save \(roundedPercentage)%" : nil
    }

    /// Get the most cost-effective subscription (lowest cost per day)
    public func getMostCostEffectiveProduct() -> Product? {
        guard !products.isEmpty else { return nil }
        
        var bestProduct: Product?
        var lowestCostPerDay: Decimal = Decimal.greatestFiniteMagnitude
        
        for product in products {
            // Skip products without a subscription
            guard let costPerDay = getCostPerDay(for: product) else { continue }
            
            if costPerDay < lowestCostPerDay {
                lowestCostPerDay = costPerDay
                bestProduct = product
            }
        }
        
        return bestProduct
    }
    
    private func getCostPerDay(for product: Product) -> Decimal? {
        guard let subscriptionInfo = product.subscription else { return nil }
        
        let period = subscriptionInfo.subscriptionPeriod
        let price = product.price
        
        // Convert period to days
        let daysInPeriod: Int
        switch period.unit {
        case .day:
            daysInPeriod = period.value
        case .week:
            daysInPeriod = period.value * 7
        case .month:
            daysInPeriod = period.value * 30
        case .year:
            daysInPeriod = period.value * 365
        @unknown default:
            return nil
        }
        
        let costPerDay = price / Decimal(daysInPeriod)
        return costPerDay
    }

    /// Check if a product is the most popular (most cost-effective)
    public func isMostPopular(productId: String) -> Bool {
        return getMostCostEffectiveProduct()?.id == productId
    }
    
    /// Connect to PremiumStatusManager for local status management
    public func connectToPremiumStatusManager(_ premiumStatusManager: PremiumStatusManager) {
        self.premiumStatusManager = premiumStatusManager
    }
    
    /// Disconnect from PremiumStatusManager
    public func disconnectFromPremiumStatusManager() {
        self.premiumStatusManager = nil
    }
    
    /// Get current premium status from the premium status manager
    public var isPremium: Bool {
        return premiumStatusManager?.isPremium ?? false
    }
    
    /// Check if a product has a free trial
    public func hasFreeTrial(for productId: String) -> Bool {
        guard let product = products.first(where: { $0.id == productId }) else {
            return true // Assume yes if we can't check
        }
        
        // Check if there's an introductory offer that's a free trial
        if let introOffer = product.subscription?.introductoryOffer {
            // Check if the introductory offer is a free trial (price is 0)
            return introOffer.price == 0
        }
        
        return false
    }
    
    /// Get developer guidance for subscription setup
    public func getDeveloperGuidance() -> String {
        let productIdsList = productIds.enumerated().map { index, id in
            "   \(index + 1). \(id)"
        }.joined(separator: "\n")
        
        return """
        📋 To enable subscriptions, you need to:
        
        1. 🏪 App Store Connect Setup:
           - Create subscription products in App Store Connect
           - Set up subscription groups
           - Configure pricing and availability
        
        2. 📱 App Submission:
           - Submit at least one app version for review
           - Subscriptions cannot be tested until app is in review
        
        3. 🧪 Testing Options:
           - Use StoreKit testing in Xcode for development
           - Test with sandbox accounts after app submission
           - Use TestFlight for beta testing
        
        4. 🔧 Current Product IDs:
        \(productIdsList)
        
        💡 Until setup is complete, the app will work in development mode.
        """
    }
    
    /// Check if we're in development mode (no real subscriptions available)
    public var isDevelopmentMode: Bool {
        return !isStoreKitAvailable || products.isEmpty
    }
    
    /// Present Apple's promo code redemption sheet
    @MainActor
    public func presentPromoCodeRedemption() async throws -> Bool {
        Logger.shared.debug("🎟️ Requesting promo code redemption sheet", category: .subscription)
        
        // Set the flag to show promo code redemption sheet
        // The actual presentation will be handled by the view using .offerCodeRedemption modifier
        Logger.shared.debug("🎟️ Setting showPromoCodeRedemption = true", category: .subscription)
        
        // Since this class is @MainActor, we're already on the main thread
        showPromoCodeRedemption = true
        
        Logger.shared.debug("🎟️ Promo code redemption sheet requested, flag is now: \(showPromoCodeRedemption)", category: .subscription)
        
        // Check current subscription status after redemption attempt
        await checkSubscriptionStatus()
        return premiumStatusManager?.isPremium ?? false
    }
    
    // Published property to control promo code redemption sheet
    @Published public var showPromoCodeRedemption = false
}
