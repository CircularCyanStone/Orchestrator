// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：基于 Mach-O Section 注入的自动发现方案 (Objective-C/C 宏注册版)。

import Foundation
import MachO

/// Mach-O Section 发现器 (Objective-C 版)
///
/// **核心原理：**
/// 读取由 `OH_REGISTER_MODULE` / `OH_REGISTER_PLUGIN` 宏注入的 Section 数据。
/// 这些宏在 Section 中存储的是 `static const char *` 指针。
///
/// - 职责：扫描 `__DATA` 段下的 `__coo_mod` 和 `__coo_svc` Section。
/// - 数据格式：`UnsafePointer<CChar>` (即 `char *`)
public struct OhObjcSectionLoader: OhPluginLoader {

    // MARK: - Constants

    /// 插件注册段名
    private static let sectionPlugin = "__coo_svc"

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
                OhLogger.log("OhObjcSectionLoader: Class '\(className)' in \(Self.sectionPlugin) is not a valid OhPlugin.", level: .warning)
            }
        }

        let cost = CFAbsoluteTimeGetCurrent() - start
        if !results.isEmpty {
            OhLogger.logPerf("OhObjcSectionLoader: Scanned \(pluginClasses.count) plugins. Cost: \(String(format: "%.4fs", cost))")
        }

        return results
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
