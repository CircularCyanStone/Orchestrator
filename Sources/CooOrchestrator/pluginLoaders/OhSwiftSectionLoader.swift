// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：基于 Mach-O Section 注入的自动发现方案 (Swift Macro 注册版)。

import Foundation
import MachO

/// Mach-O Section 发现器 (Swift Macro 版)
///
/// **核心原理：**
/// 读取由 `@OrchPlugin` 宏注入的 Section 数据。
/// 这些宏在 Section 中存储的是 `StaticString` 结构体。
///
/// - 职责：扫描 `__DATA` 段下的 `__coo_sw_mod` 和 `__coo_sw_svc` Section。
/// - 数据格式：`StaticString`
public struct OhSwiftSectionLoader: OhPluginLoader {

    // MARK: - Constants

    /// 插件注册段名
    private static let sectionPlugin = "__coo_sw_svc"

    // MARK: - Init

    public init() {}

    // MARK: - OhPluginLoader

    public func load() -> [OhPluginDefinition] {
        var results: [OhPluginDefinition] = []
        let start = CFAbsoluteTimeGetCurrent()

        let pluginClasses = scanMachO(sectionName: Self.sectionPlugin)
        for className in pluginClasses {
            if let type = NSClassFromString(className) as? (any OhPlugin.Type) {
                let def = OhPluginDefinition.plugin(type)
                results.append(def)
            } else {
                OhLogger.log("OhSwiftSectionLoader: Class '\(className)' in \(Self.sectionPlugin) is not a valid OhPlugin.", level: .warning)
            }
        }

        let cost = CFAbsoluteTimeGetCurrent() - start
        if !results.isEmpty {
            OhLogger.logPerf("OhSwiftSectionLoader: Scanned \(pluginClasses.count) plugins. Cost: \(String(format: "%.4fs", cost))")
        }

        return results
    }

    // MARK: - Mach-O Scanning

    private func scanMachO(sectionName: String) -> Set<String> {
        let entries = SectionReader.read(StaticString.self, section: sectionName)

        var classNames = Set<String>()
        for staticStr in entries {
            let str = "\(staticStr)"
            if !str.isEmpty {
                classNames.insert(str)
            }
        }
        return classNames
    }
}
