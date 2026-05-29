// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：定义插件描述符，用于从清单文件或宏生成插件元数据，支持延迟实例化。

import Foundation

/// 基于模块的插件提供者协议
/// - 职责：分模块提供一组插件描述符，用于主工程在OhModules.plist里或者通过MachO进行注册。
/// OhModules.plist里面注册的都是实现该协议的类型。MachO里面也可以基于模块进行注册。
/// - 适用：只服务于通过OhModuleLoader方式去注册插件。
public protocol OhModulePluginProvider {
    /// 必须提供无参初始化，以便框架通过反射自动加载
    init()
    /// 提供插件列表
    func providePlugins() -> [OhPluginDefinition]
}

/// 插件配置源协议 (Infrastructure Loader)
/// - 职责：执行发现逻辑，加载插件提供者。用于发现项目中注册的插件，并提供给组件内部使用。
///     如果需要自定义插件的发现逻辑需要实现该协议；组件内已内置4种方案。
/// - 适用：OhManifestLoader, OhModuleLoader 等
public protocol OhPluginLoader {
    /// 必须提供无参初始化，以便框架通过反射自动加载
    init()
    /// 加载插件描述符
    func load() -> [OhPluginDefinition]
}

/// 插件描述符（对应 Manifest 中的一条配置）
public struct OhPluginDefinition: @unchecked Sendable, CustomDebugStringConvertible {

    /// 插件类
    let pluginClass: AnyClass

    /// 工厂类（可选）
    let factoryClass: AnyClass?

    /// 指定优先级（可选）
    let priority: OhPriority?
    /// 指定持有策略（可选）
    let retentionPolicy: OhRetentionPolicy?
    /// 静态参数
    let args: [String: Sendable]
    public var debugDescription: String {
        """
            pluginClass: \(NSStringFromClass(pluginClass))
            factoryClass: \(factoryClass != nil ? NSStringFromClass(factoryClass!) : "")
            priority: \(String(describing: priority?.rawValue))
            retentionPolicy: \(retentionPolicy == .hold ? "hold" : "destroy")
            args: \(args)
        """
    }

    public init(pluginClass: AnyClass,
                priority: OhPriority? = nil,
                retentionPolicy: OhRetentionPolicy? = nil,
                args: [String: Sendable] = [:],
                factoryClass: AnyClass? = nil) {
        self.pluginClass = pluginClass
        self.priority = priority
        self.retentionPolicy = retentionPolicy
        self.args = args
        self.factoryClass = factoryClass
    }
}

// MARK: - Convenient Builder
public extension OhPluginDefinition {
    /// 便捷构造器（泛型约束，类型安全）
    /// - Parameters:
    ///   - type: 插件类型 (必须遵循 OhPlugin)
    ///   - priority: 优先级
    ///   - retention: 驻留策略
    ///   - args: 参数
    /// - Returns: 描述符实例
    static func plugin<T: OhPlugin>(
        _ type: T.Type,
        priority: OhPriority? = nil,
        retention: OhRetentionPolicy? = nil,
        args: [String: Sendable] = [:]
    ) -> OhPluginDefinition {
        return OhPluginDefinition(
            pluginClass: type,
            priority: priority,
            retentionPolicy: retention,
            args: args
        )
    }
}
