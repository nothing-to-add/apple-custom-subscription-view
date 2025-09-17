# CustomSubscription

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016%2B%20|%20macOS%2013%2B%20|%20watchOS%209%2B%20|%20visionOS%201%2B-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/release/nothing-to-add/apple-custom-subscription-view.svg)](https://github.com/nothing-to-add/apple-custom-subscription-view/releases)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

A comprehensive subscription management package for Apple platforms that provides a ready-to-use subscription view with subscription management, premium status tracking, and seamless StoreKit integration.

## 📱 Features

- ✅ **Ready-to-use subscription view** with beautiful UI
- 🔄 **Automatic subscription management** with StoreKit 2
- 💎 **Premium status tracking** across app lifecycle
- 🎯 **Feature gating** for premium functionality
- 🔔 **NotificationCenter integration** for status changes
- 🎨 **Customizable premium features** display
- 💰 **Multiple pricing plans** support
- 🆓 **Free trial** management
- 📱 **Cross-platform** support (iOS, macOS, watchOS, visionOS)
- 🧪 **Sandbox testing** support

## 📦 Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/nothing-to-add/apple-custom-subscription-view.git", from: "1.0.0")
]
```

Or add it through Xcode:

1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/nothing-to-add/apple-custom-subscription-view.git`
3. Select the version and add to your target

## 🚀 Quick Start

### 1. Import the Package

```swift
import CustomSubscription
```

### 2. Set up Environment Objects

```swift
import SwiftUI
import CustomSubscription

@main
struct MyApp: App {
    @StateObject private var premiumStatusManager = PremiumStatusManager()
    @StateObject private var subscriptionManager = SubscriptionManager(
        productIds: ["com.yourapp.monthly", "com.yourapp.annual"],
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
        termsOfServiceURL: "https://yourapp.com/terms",
        privacyPolicyURL: "https://yourapp.com/privacy"
    )
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(premiumStatusManager)
                .environmentObject(subscriptionManager)
                .task {
                    // Start subscription monitoring
                    premiumStatusManager.startSubscriptionMonitoring(subscriptionManager: subscriptionManager)
                    
                    // Check current premium status
                    await premiumStatusManager.checkPremiumStatus(subscriptionManager: subscriptionManager)
                    
                    // Schedule periodic checks
                    premiumStatusManager.schedulePeriodicChecks(subscriptionManager: subscriptionManager)
                }
        }
    }
}
```

### 3. Present the Subscription View

#### Standard Presentation

```swift
import SwiftUI
import CustomSubscription

struct ContentView: View {
    @EnvironmentObject var premiumStatusManager: PremiumStatusManager
    @State private var showSubscription = false
    
    var body: some View {
        VStack {
            Button("Upgrade to Premium") {
                showSubscription = true
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }
}
```

#### Onboarding Flow

```swift
struct OnboardingView: View {
    @State private var showingMainApp = false
    
    var body: some View {
        SubscriptionView(
            onSkip: {
                // User skipped subscription
                showingMainApp = true
            },
            onSubscribe: {
                // User subscribed
                showingMainApp = true
            }
        )
        .fullScreenCover(isPresented: $showingMainApp) {
            MainAppView()
        }
    }
}
```

### 4. Feature Gating

```swift
struct PremiumFeatureView: View {
    @EnvironmentObject var premiumStatusManager: PremiumStatusManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showSubscription = false
    
    var body: some View {
        VStack {
            if premiumStatusManager.hasPremiumAccess {
                // Show premium content
                Text("🎉 Premium Feature Unlocked!")
                    .font(.title)
            } else {
                // Show upgrade prompt
                VStack {
                    Text("This is a premium feature")
                    Button("Upgrade Now") {
                        showSubscription = true
                    }
                }
            }
        }
        .onAppear {
            // Verify premium status when accessing premium features
            premiumStatusManager.requiresPremiumAccess(subscriptionManager: subscriptionManager) { hasAccess in
                if !hasAccess {
                    showSubscription = true
                }
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }
}
```

## 🔔 NotificationCenter Integration

The package automatically posts notifications when the premium status changes. You can observe these notifications to update your UI or perform actions when the subscription status changes.

### Setting Up Notification Observers

```swift
import CustomSubscription

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Observe premium status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(premiumStatusDidChange(_:)),
            name: .premiumStatusDidChange,
            object: nil
        )
    }
    
    @objc private func premiumStatusDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isPremium = userInfo["isPremium"] as? Bool else {
            return
        }
        
        DispatchQueue.main.async {
            if isPremium {
                // User became premium
                self.handlePremiumActivated()
            } else {
                // User lost premium access
                self.handlePremiumDeactivated()
            }
        }
    }
    
    private func handlePremiumActivated() {
        // Update UI for premium user
        print("User is now premium!")
    }
    
    private func handlePremiumDeactivated() {
        // Update UI for free user
        print("User is no longer premium")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

### SwiftUI Integration

```swift
struct MyView: View {
    @EnvironmentObject var premiumStatusManager: PremiumStatusManager
    @State private var isListeningForChanges = false
    
    var body: some View {
        VStack {
            Text(premiumStatusManager.isPremium ? "Premium User" : "Free User")
        }
        .onReceive(NotificationCenter.default.publisher(for: .premiumStatusDidChange)) { notification in
            guard let userInfo = notification.userInfo,
                  let isPremium = userInfo["isPremium"] as? Bool else {
                return
            }
            
            // Handle the status change
            print("Premium status changed to: \(isPremium)")
        }
    }
}
```

### Available Notifications

| Notification Name | User Info | Description |
|------------------|-----------|-------------|
| `.premiumStatusDidChange` | `["isPremium": Bool]` | Posted when the user's premium status changes |

## ⚙️ Configuration

### SubscriptionManager Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `productIds` | `[String]` | Array of your App Store subscription product IDs |
| `premiumFeatures` | `[PremiumFeature]` | Features to display in the subscription view |
| `trialPeriodDays` | `Int` | Number of free trial days |
| `termsOfServiceURL` | `String` | URL to your terms of service |
| `privacyPolicyURL` | `String` | URL to your privacy policy |
| `headerTitle` | `String?` | Custom header title (optional) |
| `headerSubtitle` | `String?` | Custom header subtitle (optional) |

### PremiumFeature Structure

```swift
PremiumFeature(
    icon: "star.fill",           // SF Symbol name
    title: "Feature Title",     // Feature name
    description: "Description"   // Feature description
)
```

## 🧪 Testing

The package includes comprehensive testing support:

### Sandbox Testing

The subscription view automatically detects sandbox mode and displays appropriate debug information in development builds.

### Debug Information

```swift
// Get debug information about premium status
let debugInfo = premiumStatusManager.getDebugInfo()
print(debugInfo)
```

## 📋 Requirements

- iOS 16.0+ / macOS 13.0+ / watchOS 9.0+ / visionOS 1.0+
- Swift 6.0+
- Xcode 16.0+

## 🔗 Dependencies

This package depends on:

- [apple-custom-toast-manager](https://github.com/nothing-to-add/apple-custom-toast-manager) - For user feedback and notifications
- [apple-custom-logger](https://github.com/nothing-to-add/apple-custom-logger) - For comprehensive logging

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

If you have any questions or need help integrating this package, please [open an issue](https://github.com/nothing-to-add/apple-custom-subscription-view/issues).

---

Made with ❤️ for the Apple developer community