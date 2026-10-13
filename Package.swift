// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// - Note: `@OrchPlugin` 宏生成的属性名随编译器版本切换（宏内部展开为
//   `#if compiler(>=6.3) @used/@section #else @_used/@_section #endif`）：
//     - Swift 6.3+（Xcode 26.4+）：正式名 `@used` / `@section`，无需任何额外设置；
//     - Swift 6.2.x 及更早（Xcode 26.3 及更早）：只有下划线实验名，**使用该宏的
//       target** 必须开启 `-enable-experimental-feature SymbolLinkageMarkers`。
//   本包 target 已按编译器版本自动添加该开关；外部集成方在旧工具链上需自行添加，
//   详见 README 的「方案一 → 旧工具链（Xcode ≤ 26.3）」一节。
//   另：Swift 6.3 起 `@section` 静态量的初始化器必须能被常量求值器求值，详见
//   `Sources/CooOrchestrator/pluginLoaders/OhPluginSectionDecoder.swift`。

import PackageDescription
import CompilerPluginSupport

// Swift 6.2.x 及更早：`@_used` / `@_section` 仍在 SymbolLinkageMarkers 实验特性后面，
// 凡是要展开 `@OrchPlugin`（或手写这两个属性）的 target 都必须显式开启它。
// 6.3+ 已无此实验特性（传了也会被忽略），因此按编译器版本条件添加。
#if compiler(<6.3)
let sectionLinkageSettings: [SwiftSetting] = [.enableExperimentalFeature("SymbolLinkageMarkers")]
#else
let sectionLinkageSettings: [SwiftSetting] = []
#endif

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
            swiftSettings: sectionLinkageSettings
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
            ],
            swiftSettings: sectionLinkageSettings
        ),
    ],
    swiftLanguageVersions: [
        .v5,
        .version("6")
    ]
)
