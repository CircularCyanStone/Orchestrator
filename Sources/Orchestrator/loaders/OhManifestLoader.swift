// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：读取各模块私有清单（Info.plist 或资源 OhServices.plist），解析为服务描述符集合并提供统一的加载入口。
// 类型功能描述：OhManifestScanner 负责从 bundle 中发现并解析清单；ManifestKeys/ValueParser 提供键名与枚举值解析。

/**
 注册文件统一命名为OhServices.plist
 1. 当模块是静态库的framework时，plist注册文件需要手动在主工程里引用，
    即使将注册文件打包到framework里面也需要手动引用。
    仅将framework拖拽到项目中，并不会自动引用里面的资源文件。
    同时为了避免和主项目以及其他模块的注册文件冲突，需自定义xxx.bundle/OhServices.plist
 2. 动态库因为是一个编译链接的完整产物，所以资源文件直接打包到framework中，在动态链接后可直接从framework中获取到。
 */

import Foundation

/// 清单键名常量
enum ManifestKeys {
    static let root = "OhServices"
    static let className = "class"
    static let priority = "priority"
    static let retention = "retention"
    static let args = "args"
    static let factory = "factory"
}

/// Manifest 解析器
/// - 职责：从各模块私有清单读取服务配置并转换为统一的 `OhServiceDefinition` 集合。
public struct OhManifestLoader: OhServiceLoader {
    
    public init() {}
    
    public func load() -> [OhServiceDefinition] {
        return Self.loadAllDefinitions()
    }
    
    /// 线程安全的描述符收集器
    private class DescriptorCollector: @unchecked Sendable {
        private var items: [OhServiceDefinition] = []
        private let lock = NSLock()
        
        func append(_ newItems: [OhServiceDefinition]) {
            lock.lock()
            items.append(contentsOf: newItems)
            lock.unlock()
        }
        
        var allItems: [OhServiceDefinition] {
            lock.lock()
            defer { lock.unlock() }
            return items
        }
    }

    /// 加载主应用与所有已加载框架的清单并合并
    /// - Returns: 解析得到的服务描述符数组
    static func loadAllDefinitions() -> [OhServiceDefinition] {
        let start = CFAbsoluteTimeGetCurrent()
        var result: [OhServiceDefinition] = []
        
        // 1. 获取目标 Bundles (Main + Embedded Frameworks)
        let findBundleStart = CFAbsoluteTimeGetCurrent()
        var targetBundles = [Bundle.main]
        
        // 2. 扫描 Frameworks 目录 (动态库)
        if let frameworksURL = Bundle.main.privateFrameworksURL,
           let enumerator = FileManager.default.enumerator(at: frameworksURL,
                                                           includingPropertiesForKeys: nil,
                                                           options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
            for case let url as URL in enumerator {
                if url.pathExtension == "framework", let bundle = Bundle(url: url) {
                    targetBundles.append(bundle)
                }
            }
        }
        
        // 3. 扫描 Resource Bundles (静态库通常将资源打包为 .bundle 放入主包)
        // 优化: 使用 enumerator 替代 contentsOfDirectory，避免在文件极多时一次性加载所有 URL 导致的内存峰值。
        // 指定 .skipsSubdirectoryDescendants 确保只扫描根目录。
        if let resourceURL = Bundle.main.resourceURL,
           let enumerator = FileManager.default.enumerator(at: resourceURL,
                                                           includingPropertiesForKeys: nil,
                                                           options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
            for case let url as URL in enumerator {
                if url.pathExtension == "bundle", let bundle = Bundle(url: url) {
                    targetBundles.append(bundle)
                }
            }
        }
        
        let findBundleCost = CFAbsoluteTimeGetCurrent() - findBundleStart
        
        // 4. 扫描 Bundles (并发优化)
        let scanStart = CFAbsoluteTimeGetCurrent()
        
        // 使用 Collector 封装锁与状态，规避闭包捕获 var 的检查
        let collector = DescriptorCollector()
        let bundlesToScan = targetBundles
        
        DispatchQueue.concurrentPerform(iterations: bundlesToScan.count) { index in
            let bundle = bundlesToScan[index]
            let descriptors = loadDefinitions(in: bundle)
            if !descriptors.isEmpty {
                collector.append(descriptors)
            }
        }
        result.append(contentsOf: collector.allItems)
        
        let scanCost = CFAbsoluteTimeGetCurrent() - scanStart
        
        let end = CFAbsoluteTimeGetCurrent()
        
        let totalCost = end - start
        var logMsg = "OhManifestLoader: Scanned \(targetBundles.count) bundles, found \(result.count) services. Cost: \(String(format: "%.4fs", totalCost))\n"
        logMsg += " - Find Bundles   : \(String(format: "%.4fs", findBundleCost))\n"
        logMsg += " - Scan Bundles   : \(String(format: "%.4fs", scanCost))"
        
        OhLogger.logPerf(logMsg)
        
        return result
    }
    
    /// 加载指定 `bundle` 内的清单
    /// - Parameter bundle: 目标模块的 bundle
    /// - Returns: 解析结果数组；若未配置清单则返回空数组
    static func loadDefinitions(in bundle: Bundle) -> [OhServiceDefinition] {
        var descs: [OhServiceDefinition] = []
        let start = CFAbsoluteTimeGetCurrent()
        
        // 1. Info.plist (极速，推荐)
        if let info = bundle.infoDictionary {
            if let arr = info[ManifestKeys.root] as? [[String: Sendable]] {
                descs.append(contentsOf: parse(array: arr))
            }
        }
        let afterInfo = CFAbsoluteTimeGetCurrent()
        
        // 2. Resource plist (独立文件，仅作兼容，不推荐)
        var resIOCost: TimeInterval = 0
        var resParseCost: TimeInterval = 0
        
        if let url = bundle.url(forResource: "OhServices", withExtension: "plist") {
            let ioStart = CFAbsoluteTimeGetCurrent()
            // 细分IO：Data读取 vs Plist反序列化
            if let arr = NSArray(contentsOf: url) as? [[String: Sendable]] {
                // IO部分结束（含反序列化）
                resIOCost = CFAbsoluteTimeGetCurrent() - ioStart
                
                // Parse部分
                let parseStart = CFAbsoluteTimeGetCurrent()
                let parsed = parse(array: arr)
                resParseCost = CFAbsoluteTimeGetCurrent() - parseStart
                
                descs.append(contentsOf: parsed)
            }
        }
        let afterRes = CFAbsoluteTimeGetCurrent()
        
        // 统计耗时
        let totalCost = afterRes - start
        let infoCost = afterInfo - start
        let resTotalCost = afterRes - afterInfo
        
        // 强制输出，不受阈值限制，便于调试
        var msg = " - Scan \(bundle.bundleIdentifier ?? "unknown"): \(String(format: "%.6fs", totalCost))\n"
        msg += "   |-- Info: \(String(format: "%.6fs", infoCost))\n"
        msg += "   |-- Res : \(String(format: "%.6fs", resTotalCost)) (IO: \(String(format: "%.6fs", resIOCost)), Parse: \(String(format: "%.6fs", resParseCost)))"
        
        OhLogger.logPerf(msg)
        
        return descs
    }
    
    /// 将清单数组转换为描述符数组
    /// - Parameter array: 解析到的数组对象
    /// - Returns: 合法条目的 `OhServiceDefinition` 列表
    private static func parse(array: [[String: Sendable]]) -> [OhServiceDefinition] {
        var list: [OhServiceDefinition] = []
        for item in array {
            guard let className = item[ManifestKeys.className] as? String else {
                OhLogger.log("className not exsit in manifest.", level: .warning)
                continue
            }
            
            // 立即转换为 Class，如果转换失败则跳过
            guard let serviceClass = NSClassFromString(className) else {
                OhLogger.log("Failed to resolve class '\(className)' from manifest.", level: .warning)
                continue
            }
            
            let retentionStr = item[ManifestKeys.retention] as? String
            let priorityVal = item[ManifestKeys.priority] as? Int
            let args = item[ManifestKeys.args] as? [String: Sendable] ?? [:]
            let factoryName = item[ManifestKeys.factory] as? String
            
            var factoryClass: AnyClass? = nil
            if let fName = factoryName {
                factoryClass = NSClassFromString(fName)
                if factoryClass == nil {
                     OhLogger.log("Failed to resolve factory class '\(fName)' for service '\(className)'.", level: .warning)
                }
            }
            
            let retention = retentionStr.flatMap(OhRetentionPolicy.init(rawValue:))
            let priority = priorityVal.map { OhPriority(rawValue: $0) }
            
            list.append(OhServiceDefinition(serviceClass: serviceClass,
                                       priority: priority,
                                       retentionPolicy: retention,
                                       args: args,
                                       factoryClass: factoryClass))
        }
        return list
    }
}
