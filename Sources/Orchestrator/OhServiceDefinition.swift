// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：定义服务描述符，用于从清单文件或宏生成服务元数据，支持延迟实例化。

import Foundation

/// 基于模块的服务提供者协议
/// - 职责：分模块提供一组服务描述符，用于主工程在OhModules.plist里或者通过MachO进行注册。
/// OhModules.plist里面注册的都是实现该协议的类型。MachO里面也可以基于模块进行注册。
/// - 适用：只服务于通过OhModuleLoader方式去注册服务。
public protocol OhModuleServicesProvider {
    /// 必须提供无参初始化，以便框架通过反射自动加载
    init()
    /// 提供服务列表
    func provideServices() -> [OhServiceDefinition]
}

/// 服务配置源协议 (Infrastructure Loader)
/// - 职责：执行发现逻辑，加载服务提供者。用于发现项目中注册的服务，并提供给组件内部使用。
///     如果需要自定义服务的发现逻辑需要实现该协议；组件内已内置4种方案。
/// - 适用：OhManifestLoader, OhModuleLoader 等
public protocol OhServiceLoader {
    /// 必须提供无参初始化，以便框架通过反射自动加载
    init()
    /// 加载服务描述符
    func load() -> [OhServiceDefinition]
}

/// 服务描述符（对应 Manifest 中的一条配置）
public struct OhServiceDefinition: @unchecked Sendable, CustomDebugStringConvertible {
    
    /// 服务类
    let serviceClass: AnyClass
    
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
            serviceClass: \(NSStringFromClass(serviceClass))
            factoryClass: \(factoryClass != nil ? NSStringFromClass(factoryClass!) : "")
            priority: \(String(describing: priority?.rawValue))
            retentionPolicy: \(retentionPolicy == .hold ? "hold" : "destory")
            args: \(args)
        """
    }
    
    public init(serviceClass: AnyClass,
                priority: OhPriority? = nil,
                retentionPolicy: OhRetentionPolicy? = nil,
                args: [String: Sendable] = [:],
                factoryClass: AnyClass? = nil) {
        self.serviceClass = serviceClass
        self.priority = priority
        self.retentionPolicy = retentionPolicy
        self.args = args
        self.factoryClass = factoryClass
    }
}

// MARK: - Convenient Builder
public extension OhServiceDefinition {
    /// 便捷构造器（泛型约束，类型安全）
    /// - Parameters:
    ///   - type: 服务类型 (必须遵循 OhService)
    ///   - priority: 优先级
    ///   - retention: 驻留策略
    ///   - args: 参数
    /// - Returns: 描述符实例
    static func service<T: OhService>(
        _ type: T.Type,
        priority: OhPriority? = nil,
        retention: OhRetentionPolicy? = nil,
        args: [String: Sendable] = [:]
    ) -> OhServiceDefinition {
        return OhServiceDefinition(
            serviceClass: type,
            priority: priority,
            retentionPolicy: retention,
            args: args
        )
    }
}
