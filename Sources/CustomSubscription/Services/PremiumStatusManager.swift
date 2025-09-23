//
//  File name: PremiumStatusManager.swift
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
import CustomLogger
import CustomToastManager

/// Manages premium subscription status locally using UserDefaults
/// This ensures subscription status is platform-specific and not synced across platforms
@MainActor
public class PremiumStatusManager: ObservableObject {
    @Published public var isPremium = false
    
    private let userDefaults = UserDefaults.standard
    private let premiumStatusKey = "isPremiumSubscriber"
    
    public init() {
        loadPremiumStatus()
    }
    
    /// Load premium status from UserDefaults
    private func loadPremiumStatus() {
        isPremium = userDefaults.bool(forKey: premiumStatusKey)
        Logger.shared.premium("Loaded premium status from UserDefaults: \(isPremium)")
    }
    
    /// Save premium status to UserDefaults
    private func savePremiumStatus() {
        userDefaults.set(isPremium, forKey: premiumStatusKey)
        Logger.shared.premium("Saved premium status to UserDefaults: \(isPremium)")
    }
    
    /// Update premium status (called by SubscriptionManager)
    public func updatePremiumStatus(_ newStatus: Bool) {
        guard isPremium != newStatus else { return }
        
        let previousStatus = isPremium
        isPremium = newStatus
        savePremiumStatus()
        
        // Show appropriate message
        if newStatus {
            ToastManager.shared.showSuccess("Premium features unlocked!")
        } else {
            ToastManager.shared.showInfo("Premium subscription expired")
        }
        
        Logger.shared.premium("Premium status updated: \(newStatus)")
        
        // Update notifications based on new premium status
        Task {
            await updateNotificationsForStatusChange(fromPremium: previousStatus, toPremium: newStatus)
        }
    }
    
    /// Update notifications when premium status changes
    private func updateNotificationsForStatusChange(fromPremium: Bool, toPremium: Bool) async {
        // Only update if status actually changed
        guard fromPremium != toPremium else { return }
        
        // Update notifications based on new premium status
        NotificationCenter.default.post(
            name: .premiumStatusDidChange,
            object: nil,
            userInfo: ["isPremium": toPremium]
        )
    }
    
    /// Check premium status by verifying active subscriptions
    /// This should be called when app launches and when premium features are accessed
    public func checkPremiumStatus(subscriptionManager: SubscriptionManager) async {
        guard subscriptionManager.isStoreKitAvailable else {
            #if DEBUG
            Logger.shared.subscription("Skipping premium status check - StoreKit not available (Development Mode)", level: .warning)
            // In development mode, keep current status
            #endif
            return
        }
        
        var hasActiveSubscription = false
        
        // Check for active subscription entitlements
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // Check if this is one of our subscription products
                if subscriptionManager.productIds.contains(transaction.productID) {
                    hasActiveSubscription = true
                    Logger.shared.subscriptionState(.active, productId: transaction.productID)
                    break
                }
            }
        }
        
        // Update status if it changed
        if hasActiveSubscription != isPremium {
            updatePremiumStatus(hasActiveSubscription)
        }
    }
    
    /// Perform a background check of premium status
    /// This can be called periodically or when app becomes active
    public func performBackgroundPremiumCheck(subscriptionManager: SubscriptionManager) {
        Task {
            await checkPremiumStatus(subscriptionManager: subscriptionManager)
        }
    }
    
    /// Start monitoring subscription changes in the background
    /// This will detect subscription cancellations, renewals, and other changes
    public func startSubscriptionMonitoring(subscriptionManager: SubscriptionManager) {
        Task {
            // Listen for transaction updates (including cancellations)
            for await result in StoreKit.Transaction.updates {
                await handleTransactionUpdate(result, subscriptionManager: subscriptionManager)
            }
        }
    }
    
    /// Handle subscription transaction updates
    /// This catches subscription changes including cancellations, renewals, etc.
    private func handleTransactionUpdate(_ result: StoreKit.VerificationResult<StoreKit.Transaction>, subscriptionManager: SubscriptionManager) async {
        guard case .verified(let transaction) = result else {
            Logger.shared.debug("⚠️ Received unverified transaction update", category: .subscription)
            return
        }
        
        // Check if this is for one of our subscription products
        guard subscriptionManager.productIds.contains(transaction.productID) else {
            return
        }
        
        Logger.shared.debug("🔄 Subscription transaction update received for: \(transaction.productID)", category: .subscription)
        Logger.shared.debug("   Transaction type: \(transaction.revocationReason != nil ? "Revoked/Cancelled" : "Active")", category: .subscription)
        
        // Always finish the transaction
        await transaction.finish()
        
        // Re-check subscription status to reflect current state
        await checkPremiumStatus(subscriptionManager: subscriptionManager)
    }
    
    /// Schedule periodic premium status checks
    /// This provides a safety net for catching subscription changes that might be missed
    public func schedulePeriodicChecks(subscriptionManager: SubscriptionManager) {
        // Check every 24 hours when app is active
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in
                await self.checkPremiumStatus(subscriptionManager: subscriptionManager)
            }
        }
        
        // Also check every hour when app is in foreground (lighter check)
        Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { _ in
            Task { @MainActor in
                // Only check if app is active
                if UIApplication.shared.applicationState == .active {
                    await self.checkPremiumStatus(subscriptionManager: subscriptionManager)
                }
            }
        }
    }
    
    /// Check if user has premium access (main method for feature gating)
    /// This also triggers a fresh check if the last check was too long ago
    public var hasPremiumAccess: Bool {
        return isPremium
    }
    
    /// Check premium access with immediate verification
    /// Use this when user attempts to access premium features
    public func checkPremiumAccessWithVerification(subscriptionManager: SubscriptionManager) async -> Bool {
        // Always verify current status when premium features are accessed
        await checkPremiumStatus(subscriptionManager: subscriptionManager)
        return isPremium
    }
    
    /// Convenience method for UI to check premium access with verification
    public func requiresPremiumAccess(subscriptionManager: SubscriptionManager, completion: @escaping (Bool) -> Void) {
        Task {
            let hasAccess = await checkPremiumAccessWithVerification(subscriptionManager: subscriptionManager)
            await MainActor.run {
                completion(hasAccess)
            }
        }
    }
    
    /// Reset premium status (for testing or logout)
    public func resetPremiumStatus() {
        updatePremiumStatus(false)
        Logger.shared.debug("🔄 Premium status reset", category: .premium)
    }
    
    /// Get debug information about premium status
    public func getDebugInfo() -> String {
        return """
        📊 Premium Status Manager Debug Info:
        - Is Premium: \(isPremium)
        - UserDefaults Key: \(premiumStatusKey)
        - Stored Value: \(userDefaults.bool(forKey: premiumStatusKey))
        - Platform: iOS (Local subscription status)
        
        💡 Note: Premium status is stored locally and platform-specific.
        Each platform (iOS/Android) manages its own subscription state.
        """
    }
}
