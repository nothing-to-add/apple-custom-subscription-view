//
//  File name: CustomSubscriptionView.swift
//  Project name: apple-custom-subscription-view
//  Workspace name: apple-custom-subscription-view
//
//  Created by: nothing-to-add on 16/09/2025
//  Using Swift 6.0
//  Copyright (c) 2023 nothing-to-add
//

import SwiftUI
import StoreKit

public struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var premiumStatusManager: PremiumStatusManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedProductId: String = ""
    @State private var showSafariForTerms = false
    @State private var showSafariForPrivacy = false
    
    // Onboarding flow callbacks
    let onSkip: (() -> Void)?
    let onSubscribe: (() -> Void)?
    
    // Computed property to determine if we're in onboarding flow
    private var isOnboardingFlow: Bool {
        onSkip != nil && onSubscribe != nil
    }
    
    // Dynamic pricing text based on available products
    private var dynamicPricingText: LocalizedStringResource {
        let products = subscriptionManager.products
        if products.isEmpty {
            return "\(subscriptionManager.trialPeriodDays)-day free trial, then subscription pricing applies"
        }
        
        let priceTexts = products.map { product in
            "\(subscriptionManager.formattedPrice(for: product.id))/\(getShortPeriod(for: product.id))"
        }
        
        if priceTexts.count == 1 {
            return "\(subscriptionManager.trialPeriodDays)-day free trial, then \(priceTexts[0])"
        } else if priceTexts.count == 2 {
            return "\(subscriptionManager.trialPeriodDays)-day free trial, then \(priceTexts[0]) or \(priceTexts[1])"
        } else {
            return "\(subscriptionManager.trialPeriodDays)-day free trial, then \(priceTexts.joined(separator: ", "))"
        }
    }
    
    // Helper to get short period name
    private func getShortPeriod(for productId: String) -> String {
        guard let product = subscriptionManager.products.first(where: { $0.id == productId }),
              let subscription = product.subscription else {
            return "period"
        }
        
        let period = subscription.subscriptionPeriod
        switch period.unit {
        case .day:
            return String(localized: "\(period.value) days")
        case .week:
            return String(localized: "\(period.value) weeks")
        case .month:
            return String(localized: "\(period.value) months")
        case .year:
            return String(localized: "\(period.value) years")
        @unknown default:
            return String(localized: "period")
        }
    }
    
    public init(onSkip: (() -> Void)? = nil, onSubscribe: (() -> Void)? = nil) {
        self.onSkip = onSkip
        self.onSubscribe = onSubscribe
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    header
                    
                    // Pricing Section
                    pricingSection
                    
                    // Call to Action
                    callToActionSection
                    
                    // Skip button for onboarding flow
                    if isOnboardingFlow {
                        skipSection
                    }
                    
                    // Features List
                    featuresList
                    
                    // Terms
                    termsSection
                }
                .padding()
            }
            .navigationTitle(isOnboardingFlow ? "Unlock Premium" : "Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isOnboardingFlow {
                        Button("Skip") {
                            onSkip?()
                        }
                    } else {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .task {
            // Set default selected product to the most popular (cost-effective) one
            if selectedProductId.isEmpty, let mostPopular = subscriptionManager.getMostCostEffectiveProduct() {
                selectedProductId = mostPopular.id
            }
        }
        .onAppear {
            #if DEBUG
            print("🧪 SANDBOX TESTING MODE")
            print("📦 Products to load: \(subscriptionManager.productIds)")
            print("💡 Make sure to use sandbox test account for purchases")
            #endif
        }
        .fullScreenCover(isPresented: $showSafariForTerms) {
            SafariView(url: URL(string: subscriptionManager.termsOfServiceURL)!)
        }
        .fullScreenCover(isPresented: $showSafariForPrivacy) {
            SafariView(url: URL(string: subscriptionManager.privacyPolicyURL)!)
        }
    }
    
    private var header: some View {
        VStack(spacing: 16) {
            Text(subscriptionManager.headerTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(subscriptionManager.headerSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }
    
    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Premium Features")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(subscriptionManager.premiumFeatures.indices, id: \.self) { index in
                    let feature = subscriptionManager.premiumFeatures[index]
                    FeatureRowView(feature: feature)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var pricingSection: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(subscriptionManager.products, id: \.id) { product in
                    Button(action: {
                        selectedProductId = product.id
                    }) {
                        PricingCardView(
                            title: subscriptionManager.formattedTitle(for: product.id),
                            price: subscriptionManager.formattedPrice(for: product.id),
                            period: subscriptionManager.formattedPeriod(for: product.id),
                            savings: subscriptionManager.calculateSavings(for: product.id),
                            isPopular: subscriptionManager.isMostPopular(productId: product.id),
                            isSelected: selectedProductId == product.id
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var callToActionSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                Task {
                    await subscriptionManager.purchase(productId: selectedProductId)
                    
                    // Check if purchase was successful and we're in onboarding flow
                    if isOnboardingFlow && subscriptionManager.purchaseState == .purchased {
                        onSubscribe?()
                    }
                }
            }) {
                HStack {
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(subscriptionManager.isLoading ? "Processing..." : "Start Free Trial")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(subscriptionManager.isLoading)
            .padding(.horizontal)
            
            Text(dynamicPricingText)
                .captionText()
            
            Text("Cancel anytime • Share with family")
                .captionText()
        }
    }
    
    private var skipSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                onSkip?()
            }) {
                Text("Continue with Free Version")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Text("You can always upgrade later in Settings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private var termsSection: some View {
        VStack(spacing: 12) {
            // Legal requirements text
            Text("Auto-renewable subscription. Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your App Store account settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button("Terms of Service") {
                    showSafariForTerms = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("Privacy Policy") {
                    showSafariForPrivacy = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("Restore Purchases") {
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
                .disabled(subscriptionManager.isLoading)
            }
        }
        .padding(.bottom, 20)
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(PremiumStatusManager())
        .environmentObject(SubscriptionManager(
            productIds: ["com.example.app.monthly", "com.example.app.annual"],
            premiumFeatures: [
                PremiumFeature(
                    icon: "star.fill",
                    title: "Ad-Free Experience",
                    description: "Enjoy the app without any advertisements"
                ),
                PremiumFeature(
                    icon: "bolt.fill",
                    title: "Premium Features",
                    description: "Access to all premium functionality"
                ),
                PremiumFeature(
                    icon: "cloud.fill",
                    title: "Cloud Sync",
                    description: "Sync your data across all devices"
                )
            ],
            trialPeriodDays: 7,
            termsOfServiceURL: "https://example.com/terms",
            privacyPolicyURL: "https://example.com/privacy"
        ))
}

#Preview("Onboarding Flow") {
    SubscriptionView(onSkip: {
        print("Skip pressed")
    }, onSubscribe: {
        print("Subscribe pressed")
    })
    .environmentObject(PremiumStatusManager())
    .environmentObject(SubscriptionManager(
        productIds: ["com.example.app.monthly", "com.example.app.annual"],
        premiumFeatures: [
            PremiumFeature(
                icon: "star.fill",
                title: "Ad-Free Experience",
                description: "Enjoy the app without any advertisements"
            ),
            PremiumFeature(
                icon: "bolt.fill",
                title: "Premium Features",
                description: "Access to all premium functionality"
            ),
            PremiumFeature(
                icon: "cloud.fill",
                title: "Cloud Sync",
                description: "Sync your data across all devices"
            )
        ],
        trialPeriodDays: 7,
        termsOfServiceURL: "https://example.com/terms",
        privacyPolicyURL: "https://example.com/privacy"
    ))
}
