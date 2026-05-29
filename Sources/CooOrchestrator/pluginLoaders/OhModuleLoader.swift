// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：读取主工程配置的模块列表 (OhModules.plist)，并加载对应模块的插件。

import Foundation

/// 模块配置发现器
/// - 职责：从 `OhModules.plist` 读取模块入口类名，实例化并加载其插件。
/// - 优势：显式、确定、高性能，完全解耦主工程与模块实现。
public struct OhModuleLoader: OhPluginLoader {

    public init() {}

    public func load() -> [OhPluginDefinition] {
        var result: [OhPluginDefinition] = []

        guard let modulesURL = Bundle.main.url(forResource: "OhModules", withExtension: "plist"),
              let moduleNames = NSArray(contentsOf: modulesURL) as? [String] else {
            OhLogger.log("OhModuleLoader: OhModules.plist not found or invalid.", level: .warning)
            return []
        }

        OhLogger.log("OhModuleLoader: Found \(moduleNames.count) modules in config.", level: .info)

        for className in moduleNames {
            if let moduleClass = NSClassFromString(className) as? OhModulePluginProvider.Type {
                let module = moduleClass.init()
                let descriptors = module.providePlugins()
                result.append(contentsOf: descriptors)
                OhLogger.log("OhModuleLoader: Loaded \(descriptors.count) plugins from \(className)", level: .info)
            } else {
                OhLogger.log("OhModuleLoader: Class '\(className)' not found or invalid (Must implement OhModulePluginProvider).", level: .warning)
            }
        }

        return result
    }
}
