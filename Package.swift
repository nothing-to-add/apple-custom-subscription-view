// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "apple-custom-subscription-view",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CustomSubscription",
            targets: ["CustomSubscription"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nothing-to-add/apple-custom-toast-manager.git", from: "1.0.0"),
        .package(url: "https://github.com/nothing-to-add/apple-custom-logger.git", from: "1.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CustomSubscription",
            dependencies: [
                .product(name: "CustomToastManager", package: "apple-custom-toast-manager"),
                .product(name: "CustomLogger", package: "apple-custom-logger")
            ],
            resources: [
                .process("Resources/en.lproj"),
                .process("Resources/es.lproj")
            ]),
            
//            resources: [
//                .process("Resources")
//            ]),

    ]
)
