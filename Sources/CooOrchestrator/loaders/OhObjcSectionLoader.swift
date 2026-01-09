// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：基于 Mach-O Section 注入的自动发现方案 (Objective-C/C 宏注册版)。
// 类型功能描述：OhObjcSectionScanner 扫描由 OC 宏注册的二进制段信息，读取 C 字符串指针。

import Foundation
import MachO

/// Mach-O Section 发现器 (Objective-C 版)
///
/// **核心原理：**
/// 读取由 `OH_REGISTER_MODULE` / `OH_REGISTER_SERVICE` 宏注入的 Section 数据。
/// 这些宏在 Section 中存储的是 `static const char *` 指针。
///
/// - 职责：扫描 `__DATA` 段下的 `__coo_mod` 和 `__coo_svc` Section。
/// - 数据格式：`UnsafePointer<CChar>` (即 `char *`)
public struct OhObjcSectionLoader: OhServiceLoader {
    
    // MARK: - Constants
    
    /// 服务注册段名
    private static let sectionService = "__coo_svc"
    
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
                OhLogger.log("OhObjcSectionLoader: Class '\(className)' in \(Self.sectionService) is not a valid OhService.", level: .warning)
            }
        }
        
        let cost = CFAbsoluteTimeGetCurrent() - start
        if !results.isEmpty {
            OhLogger.logPerf("OhObjcSectionLoader: Scanned \(serviceClasses.count) services. Cost: \(String(format: "%.4fs", cost))")
        }
        
        return results
    }
    
    // MARK: - Mach-O Scanning
    
    private func scanMachO(sectionName: String) -> Set<String> {
        // 使用泛型 Reader 读取 C 字符串指针数组
        // 对应 OC 宏：static const char *var = "string"
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
