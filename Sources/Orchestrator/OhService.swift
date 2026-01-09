// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：定义应用服务的基础协议，包括唯一标识、优先级、驻留策略及注册入口。
// 类型功能描述：OhService 是所有业务模块对接生命周期的入口协议；Registry 用于收集服务的回调闭包。

import Foundation


/// 服务注册表（泛型容器）
/// - 职责：收集特定服务类型的所有事件处理闭包。
/// - 设计：使用泛型 T 确保注册时的类型安全，避免强制转换。
public final class OhRegistry<T: OhService>: @unchecked Sendable {
    // 存储注册项：事件 -> 闭包
    struct Entry {
        let event: OhEvent
        let handler: (any OhService, OhContext) throws -> OhResult
    }
    
    private(set) var entries: [Entry] = []
    
    public init() {}
    
    /// 注册事件处理闭包
    /// - Parameters:
    ///   - event: 监听的生命周期事件
    ///   - handler: 处理闭包，传入具体的服务实例与上下文
    public func add(_ event: OhEvent, handler: @escaping (T, OhContext) throws -> OhResult) {
        let typeErasedHandler: (any OhService, OhContext) throws -> OhResult = { service, context in
            guard let s = service as? T else {
                throw NSError(domain: "Orchestrator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Type mismatch"])
            }
            return try handler(s, context)
        }
        entries.append(Entry(event: event, handler: typeErasedHandler))
    }
    
    /// 注册事件处理（支持 Void 返回值的便捷方法）
    /// - Parameters:
    ///   - event: 监听的生命周期事件
    ///   - handler: 处理闭包（无返回值，默认继续）
    public func add(_ event: OhEvent, handler: @escaping (T, OhContext) throws -> Void) {
        add(event) { service, context in
            try handler(service, context)
            return .continue()
        }
    }
}

/// 应用服务协议
/// - 模块/服务需遵守此协议以接收生命周期事件
public protocol OhService: AnyObject,Sendable {
    /// 服务唯一标识（默认为类名）
    static var id: String { get }
    /// 默认优先级（默认为 .medium）
    /// - Note: 数值越大，优先级越高，越先执行。
    static var priority: OhPriority { get }
    /// 默认驻留策略（默认为 .destroy，即用完即毁）
    static var retention: OhRetentionPolicy { get }
    
    /// 是否为懒加载服务
    /// - true (默认): 仅在第一次处理事件时创建实例
    /// - false: 在 Orchestrator.resolve() 阶段立即创建实例 (仅当 retention 为 .hold 时有效)
    static var isLazy: Bool { get }
    
    /// 必须提供无参构造器（用于反射或工厂创建）
    init()
    
    /// 注册服务感兴趣的事件
    /// - Parameter registry: 注册表容器
    static func register(in registry: OhRegistry<Self>)
    
    /// 服务实例创建完成后的回调，主线程回调
    /// - 用于执行初始化逻辑，替代在 didFinishLaunching 中写逻辑
    /// - 注意：此方法执行时，服务实例已创建但尚未处理任何事件
    func serviceDidResolve()
}

// MARK: - Default Implementation
public extension OhService {
    static var id: String { String(describing: self) }
    static var priority: OhPriority { .medium }
    static var retention: OhRetentionPolicy { .destroy }
    static var isLazy: Bool { true }
    func serviceDidResolve() {}
}
