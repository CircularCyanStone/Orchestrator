// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：基于 Mach-O Section 注入的自动发现方案 (Swift Macro 注册版)。
// 类型功能描述：OhSwiftSectionScanner 扫描由 Swift Macro 注册的二进制段信息，读取 StaticString。

import Foundation
import MachO

/// Mach-O Section 发现器 (Swift Macro 版)
///
/// **核心原理：**
/// 读取由 `@RegisterModule` / `@RegisterService` 宏注入的 Section 数据。
/// 这些宏在 Section 中存储的是 `StaticString` 结构体。
///
/// - 职责：扫描 `__DATA` 段下的 `__coo_sw_mod` 和 `__coo_sw_svc` Section。
/// - 数据格式：`StaticString`
public struct OhSwiftSectionLoader: OhServiceLoader {
    
    // MARK: - Constants
    
    /// 服务注册段名
    private static let sectionService = "__coo_sw_svc"
    
    // MARK: - Init
    
    public init() {}
    
    // MARK: - OhServiceLoader
    
    public func load() -> [OhServiceDefinition] {
        var results: [OhServiceDefinition] = []
        let start = CFAbsoluteTimeGetCurrent()
        
        // 扫描服务注册段
        let serviceClasses = scanMachO(sectionName: Self.sectionService)
        for className in serviceClasses {
            if let type = NSClassFromString(className) as? (any OhService.Type) {
                let def = OhServiceDefinition.service(type)
                results.append(def)
            } else {
                OhLogger.log("OhSwiftSectionLoader: Class '\(className)' in \(Self.sectionService) is not a valid OhService.", level: .warning)
            }
        }
        
        let cost = CFAbsoluteTimeGetCurrent() - start
        if !results.isEmpty {
            OhLogger.logPerf("OhSwiftSectionLoader: Scanned \(serviceClasses.count) services. Cost: \(String(format: "%.4fs", cost))")
        }
        
        return results
    }
    
    // MARK: - Mach-O Scanning
    
    private func scanMachO(sectionName: String) -> Set<String> {
        // 使用泛型 Reader 读取 StaticString 数组
        // 对应 Swift 宏：static let entry: StaticString = "string"
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
