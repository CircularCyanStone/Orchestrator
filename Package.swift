// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Orchestrator",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Orchestrator",
            type: .dynamic,
            targets: ["Orchestrator"]),
    ],
    dependencies: [
        // Depend on the latest Swift 5.9 syntax
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "509.0.0"..<"603.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .macro(
            name: "CooOrchestratorMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(
            name: "Orchestrator",
            dependencies: ["CooOrchestratorMacros"],
            swiftSettings: [.enableExperimentalFeature("SymbolLinkageMarkers")],
        ),
        .testTarget(
            name: "CooOrchestratorTests",
            dependencies: [
                "Orchestrator",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("SymbolLinkageMarkers")
            ]
        ),
    ],
    swiftLanguageVersions: [
        .v5,
        .version("6")
    ]
)
