// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：基于 Mach-O Section 注入的自动发现方案 (Objective-C/C 宏注册版)。

import Foundation
import MachO

/// Mach-O Section 发现器 (Objective-C 版)
///
/// **核心原理：**
/// 读取由 `OH_REGISTER_PLUGIN` / `OH_REGISTER_APP_PLUGIN` 宏注入的 Section 数据。
/// 这些宏在 Section 中存储的是 `static const char *` 指针。
///
/// **类名解析策略：**
/// - 含 `.` 的字符串（如 `"MyApp.Service"`）：视为完整限定名，直接传给 `NSClassFromString`。
/// - 不含 `.` 的字符串（如 `"Service"`）：先直接尝试（匹配 ObjC 类），
///   失败后自动拼接主工程的 `PRODUCT_MODULE_NAME` 再试（匹配主工程 Swift 类）。
///
/// - 职责：扫描 `__DATA` 段下的 `__coo_svc` Section。
/// - 数据格式：`UnsafePointer<CChar>` (即 `char *`)
public struct OhObjcSectionLoader: OhPluginLoader {

    // MARK: - Constants

    /// 插件注册段名
    private static let sectionPlugin = "__coo_svc"

    /// 主工程模块名，取自 `CFBundleExecutable`，默认等于 `PRODUCT_MODULE_NAME`。
    /// 懒加载，只取一次。
    private static let mainModuleName: String = {
        Bundle.main.object(forInfoDictionaryKey: kCFBundleExecutableKey as String) as? String ?? ""
    }()

    // MARK: - Init

    public init() {}

    // MARK: - OhPluginLoader

    public func load() -> [OhPluginDefinition] {
        var results: [OhPluginDefinition] = []
        let start = CFAbsoluteTimeGetCurrent()

        let pluginClasses = scanMachO(sectionName: Self.sectionPlugin)
        for className in pluginClasses {
            if let type = resolveClass(className) as? (any OhPlugin.Type) {
                let def = OhPluginDefinition.plugin(type)
                results.append(def)
            } else {
                OhLogger.log("OhObjcSectionLoader: Class '\(className)' in \(Self.sectionPlugin) is not a valid OhPlugin.", level: .warning)
            }
        }

        let cost = CFAbsoluteTimeGetCurrent() - start
        if !results.isEmpty {
            OhLogger.logPerf("OhObjcSectionLoader: Scanned \(pluginClasses.count) plugins. Cost: \(String(format: "%.4fs", cost))")
        }

        return results
    }

    // MARK: - Class Resolution

    /// 智能解析类名。
    ///
    /// 解析策略：
    /// 1. 直接尝试 `NSClassFromString(name)` — 匹配完整限定名（如 `Module.Class`）或 ObjC 类。
    /// 2. 若不含 `.`，拼接主工程模块名后再试 — 匹配主工程中的 Swift 类。
    private func resolveClass(_ name: String) -> AnyClass? {
        // 1. 直接尝试（完整 "Module.Class" 或 ObjC 类）
        if let cls = NSClassFromString(name) { return cls }

        // 2. 不含 "." → 可能是主工程的 Swift 类，尝试拼接模块名
        if !name.contains(".") {
            let fullName = "\(Self.mainModuleName).\(name)"
            if let cls = NSClassFromString(fullName) { return cls }
        }

        return nil
    }

    // MARK: - Mach-O Scanning

    private func scanMachO(sectionName: String) -> Set<String> {
        let entries = SectionReader.read(UnsafePointer<CChar>.self, section: sectionName)

        var classNames = Set<String>()
        for charPtr in entries {
            let str = String(cString: charPtr)
            if !str.isEmpty {
                classNames.insert(str)
            }
        }
        return classNames
    }
}
