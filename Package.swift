// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// - Note: `@OrchPlugin` 宏依赖 Swift 6.3 起提供的 `@used` / `@section` 属性
//   （旧名 `@_used` / `@_section` 在 6.3+ 会输出重命名警告，且 Swift 6.3 起
//   `@section` 静态量的初始化器必须能被常量求值器求值，详见
//   `Sources/CooOrchestrator/pluginLoaders/OhPluginSectionDecoder.swift`）。
//   因此使用该宏的工程需要 Swift 6.3+ 工具链；框架其它部分不受影响。

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "CooOrchestrator",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CooOrchestrator",
            targets: ["CooOrchestrator"]),
        .library(name: "CooOrchestrator-dynamic", type: .dynamic, targets: ["CooOrchestrator"])
    ],
    dependencies: [
        // Depend on the latest Swift 5.9 syntax
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "509.0.0"..<"603.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // They can depend on other targets in this package and products from dependencies.
        .macro(
            name: "CooOrchestratorMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(
            name: "CooOrchestrator",
            dependencies: ["CooOrchestratorMacros"],
        ),
        .testTarget(
            name: "CooOrchestratorTests",
            dependencies: [
                "CooOrchestrator",
                "CooOrchestratorMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageVersions: [
        .v5,
        .version("6")
    ]
)
