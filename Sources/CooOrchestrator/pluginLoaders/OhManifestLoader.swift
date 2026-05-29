// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：读取各模块私有清单（Info.plist 或资源 OhPlugins.plist），解析为插件描述符集合并提供统一的加载入口。

/**
 注册文件统一命名为 OhPlugins.plist
 1. 当模块是静态库的framework时，plist注册文件需要手动在主工程里引用，
    即使将注册文件打包到framework里面也需要手动引用。
    仅将framework拖拽到项目中，并不会自动引用里面的资源文件。
    同时为了避免和主项目以及其他模块的注册文件冲突，需自定义xxx.bundle/OhPlugins.plist
 2. 动态库因为是一个编译链接的完整产物，所以资源文件直接打包到framework中，在动态链接后可直接从framework中获取到。
 */

import Foundation

/// 清单键名常量
enum ManifestKeys {
    static let root = "OhPlugins"
    static let className = "class"
    static let priority = "priority"
    static let retention = "retention"
    static let args = "args"
    static let factory = "factory"
}

/// Manifest 解析器
/// - 职责：从各模块私有清单读取插件配置并转换为统一的 `OhPluginDefinition` 集合。
public struct OhManifestLoader: OhPluginLoader {

    public init() {}

    public func load() -> [OhPluginDefinition] {
        return Self.loadAllDefinitions()
    }

    /// 线程安全的描述符收集器
    private class DescriptorCollector: @unchecked Sendable {
        private var items: [OhPluginDefinition] = []
        private let lock = NSLock()

        func append(_ newItems: [OhPluginDefinition]) {
            lock.lock()
            items.append(contentsOf: newItems)
            lock.unlock()
        }

        var allItems: [OhPluginDefinition] {
            lock.lock()
            defer { lock.unlock() }
            return items
        }
    }

    /// 加载主应用与所有已加载框架的清单并合并
    static func loadAllDefinitions() -> [OhPluginDefinition] {
        let start = CFAbsoluteTimeGetCurrent()
        var result: [OhPluginDefinition] = []

        let findBundleStart = CFAbsoluteTimeGetCurrent()
        var targetBundles = [Bundle.main]

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

        let scanStart = CFAbsoluteTimeGetCurrent()
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
        var logMsg = "OhManifestLoader: Scanned \(targetBundles.count) bundles, found \(result.count) plugins. Cost: \(String(format: "%.4fs", totalCost))\n"
        logMsg += " - Find Bundles   : \(String(format: "%.4fs", findBundleCost))\n"
        logMsg += " - Scan Bundles   : \(String(format: "%.4fs", scanCost))"

        OhLogger.logPerf(logMsg)

        return result
    }

    /// 加载指定 `bundle` 内的清单
    static func loadDefinitions(in bundle: Bundle) -> [OhPluginDefinition] {
        var descs: [OhPluginDefinition] = []
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

        if let url = bundle.url(forResource: "OhPlugins", withExtension: "plist") {
            let ioStart = CFAbsoluteTimeGetCurrent()
            if let arr = NSArray(contentsOf: url) as? [[String: Sendable]] {
                resIOCost = CFAbsoluteTimeGetCurrent() - ioStart

                let parseStart = CFAbsoluteTimeGetCurrent()
                let parsed = parse(array: arr)
                resParseCost = CFAbsoluteTimeGetCurrent() - parseStart

                descs.append(contentsOf: parsed)
            }
        }
        let afterRes = CFAbsoluteTimeGetCurrent()

        let totalCost = afterRes - start
        let infoCost = afterInfo - start
        let resTotalCost = afterRes - afterInfo

        var msg = " - Scan \(bundle.bundleIdentifier ?? "unknown"): \(String(format: "%.6fs", totalCost))\n"
        msg += "   |-- Info: \(String(format: "%.6fs", infoCost))\n"
        msg += "   |-- Res : \(String(format: "%.6fs", resTotalCost)) (IO: \(String(format: "%.6fs", resIOCost)), Parse: \(String(format: "%.6fs", resParseCost)))"

        OhLogger.logPerf(msg)

        return descs
    }

    /// 将清单数组转换为描述符数组
    private static func parse(array: [[String: Sendable]]) -> [OhPluginDefinition] {
        var list: [OhPluginDefinition] = []
        for item in array {
            guard let className = item[ManifestKeys.className] as? String else {
                OhLogger.log("className not exist in manifest.", level: .warning)
                continue
            }

            guard let pluginClass = NSClassFromString(className) else {
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
                    OhLogger.log("Failed to resolve factory class '\(fName)' for plugin '\(className)'.", level: .warning)
                }
            }

            let retention = retentionStr.flatMap(OhRetentionPolicy.init(rawValue:))
            let priority = priorityVal.map { OhPriority(rawValue: $0) }

            list.append(OhPluginDefinition(pluginClass: pluginClass,
                                       priority: priority,
                                       retentionPolicy: retention,
                                       args: args,
                                       factoryClass: factoryClass))
        }
        return list
    }
}
