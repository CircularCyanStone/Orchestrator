// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：基于 Mach-O Section 注入的自动发现方案 (Swift Macro 注册版)。

import Foundation
import MachO

/// Mach-O Section 发现器 (Swift Macro 版)
///
/// **核心原理：**
/// 读取由 `@OrchPlugin` 宏注入的 `__DATA,__coo_sw_svc` Section 数据。
///
/// **数据格式：** 每个条目 8 个 UInt64 = 64 字节，类名的 UTF-8 字节按小端编码
/// （之所以不用 `StaticString`，是因为 Swift 6.3 起 `@section` 静态量的初始化器
/// 必须能被常量求值器求值）。格式细节见 `OhPluginSectionDecoder`。
///
/// **类名解析策略（与 `OhObjcSectionLoader` 一致）：**
/// - 含 `.` 的字符串（如 `SiKu.SKBootService`）：视为完整限定名，直接传给 `NSClassFromString`。
/// - 不含 `.` 的字符串（如 `SKBootService`）：先直接尝试，失败后自动拼接主工程的
///   `PRODUCT_MODULE_NAME`（取自 `CFBundleExecutable`）再试。
///
/// - 职责：扫描 `__DATA` 段下的 `__coo_sw_svc` Section。
public struct OhSwiftSectionLoader: OhPluginLoader {

    // MARK: - Constants

    /// 插件注册段名
    private static let sectionPlugin = "__coo_sw_svc"

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
                OhLogger.log("OhSwiftSectionLoader: Class '\(className)' in \(Self.sectionPlugin) is not a valid OhPlugin.", level: .warning)
            }
        }

        let cost = CFAbsoluteTimeGetCurrent() - start
        if !results.isEmpty {
            OhLogger.logPerf("OhSwiftSectionLoader: Scanned \(pluginClasses.count) plugins. Cost: \(String(format: "%.4fs", cost))")
        }

        return results
    }

    // MARK: - Class Resolution

    /// 智能解析类名。
    ///
    /// 解析策略：
    /// 1. 直接尝试 `NSClassFromString(name)` — 匹配完整限定名（如 `Module.Class`）。
    /// 2. 若不含 `.`，拼接主工程模块名后再试 — 匹配主工程中的 Swift 类。
    private func resolveClass(_ name: String) -> AnyClass? {
        // 1. 直接尝试（完整 "Module.Class"）
        if let cls = NSClassFromString(name) { return cls }

        // 2. 不含 "." → 可能是主工程的 Swift 类，尝试拼接模块名
        if !name.contains(".") {
            let fullName = "\(Self.mainModuleName).\(name)"
            if let cls = NSClassFromString(fullName) { return cls }
        }

        return nil
    }

    // MARK: - Mach-O Scanning

    /// 扫描 `__coo_sw_svc` Section，解码出插件类名
    private func scanMachO(sectionName: String) -> Set<String> {
        // 以 UInt8 读取 Section 原始字节，再按固定条目长度解码（见 OhPluginSectionDecoder）
        let bytes = SectionReader.read(UInt8.self, section: sectionName)
        return Set(OhPluginSectionDecoder.decodeClassNames(fromSectionBytes: bytes))
    }
}
