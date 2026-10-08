// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：定义编排插件的基础协议，包括唯一标识、优先级、驻留策略及注册入口。
// 类型功能描述：OhPlugin 是所有编排节点对接生命周期的入口协议；OhPluginRegistry 用于收集插件的回调闭包。

import Foundation

/// 插件注册表（泛型容器）
/// - 职责：收集特定插件类型的所有事件处理闭包。
/// - 设计：使用泛型 T 确保注册时的类型安全，避免强制转换。
///
/// **并发契约（`@unchecked Sendable` 的依据，改动前请先读完）：**
/// 1. **实例是一次性的**：每个实例由 `Orchestrator.invokeRegister(_:)` 创建，紧接着调用
///    `T.register(in:)` 写入，再读取 `entries` 后即被丢弃；写入与读取都发生在同一次
///    调用栈内，实例不会跨线程共享（全仓 `registry.entries` 只有那一处读取）。
/// 2. **写入在调用方的锁内**：`register(in:)` 只由 `Orchestrator.mergeDefinitions(_:)`
///    调用，而它的三个调用点（`register(_:)`、`resolve(loaders:)`、`fire(_:)` 的
///    bootstrap 分支）都在 `UnfairLock` 持有区间内，因此 `entries.append` 的并发安全
///    由**调用方的锁**保证 —— 本类型自身不加锁，也不能在多线程间共享同一个实例。
/// 3. **handler 的调用时机**：闭包被复制进 `Orchestrator.ResolvedPluginEntry` 之后，
///    才在锁外、由 `fire(_:)` 的调用者线程执行。这也是 `addScene` / `addApplication`
///    等注册入口是 `nonisolated`、却在闭包内用 `MainActor.assumeIsolated` 的原因。
/// 4. `@unchecked Sendable` 只是为了让实例能作为参数传给非隔离的 `register(in:)`，
///    它声明的是"实例独占"这一事实，而非"内部有锁"。
public final class OhPluginRegistry<T: OhPlugin>: @unchecked Sendable {
    // 存储注册项：事件 -> 闭包
    struct Entry {
        let event: OhEvent
        let handler: (any OhPlugin, OhContext) throws -> OhResult
    }

    private(set) var entries: [Entry] = []

    public init() {}

    /// 注册事件处理闭包
    /// - Parameters:
    ///   - event: 监听的生命周期事件
    ///   - handler: 处理闭包，传入具体的插件实例与上下文
    public func add(_ event: OhEvent, handler: @escaping (T, OhContext) throws -> OhResult) {
        let typeErasedHandler: (any OhPlugin, OhContext) throws -> OhResult = { plugin, context in
            guard let s = plugin as? T else {
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
        add(event) { plugin, context in
            try handler(plugin, context)
            return .continue()
        }
    }
}

// MARK: - Plugin Protocol

/// 编排插件协议
///
/// **命名约定：**
/// - 实现 `OhPlugin` 的类型称为 **Plugin（插件）**，表示"编排流程中的功能单元"。
/// - 业务层的**服务**应通过 DI 容器（如 Factory、Swinject）管理，命名为 `XXXService`。
/// - 两者职责不同：Plugin 负责在特定时机响应事件，Service 负责提供业务能力。
///
/// **何时用 Plugin vs Service：**
/// - Plugin：需要在应用生命周期某个"时机"执行逻辑（如 didFinishLaunching 时初始化 SDK）。
/// - Service：被其他模块通过依赖注入使用的业务能力（如 AuthService、UserService）。
///
/// **内置 Service Locator：**
/// - `Orchestrator` 提供了简易的实例管理能力（通过 `retention = .hold` + `Orchestrator.service(of:)`）。
/// - 这适合小型项目或无需外部 DI 工具的场景。
/// - 对于中大型项目，建议使用专业的 DI 工具管理业务服务，Orchestrator 仅负责编排。
public protocol OhPlugin: AnyObject {
    /// 插件唯一标识（默认为类名）
    static var id: String { get }
    /// 默认优先级（默认为 .medium）
    /// - Note: 数值越大，优先级越高，越先执行。
    static var priority: OhPriority { get }
    /// 默认驻留策略（默认为 .destroy，即用完即毁）
    static var retention: OhRetentionPolicy { get }

    /// 是否为懒加载插件
    /// - true (默认): 仅在第一次处理事件时创建实例
    /// - false: 在 Orchestrator.resolve() 阶段立即创建实例 (仅当 retention 为 .hold 时有效)
    static var isLazy: Bool { get }

    /// 必须提供无参构造器（用于反射或工厂创建）
    /// - Note: `@MainActor` 即契约：框架在调用前已切到主线程，
    ///   实现方不需要自行调度（可写非隔离方法，也可写 `@MainActor` 方法）。
    @MainActor init()

    /// 注册插件感兴趣的事件
    /// - Parameter registry: 注册表容器
    /// - Warning: 此方法在框架内部锁保护下执行，仅用于添加事件闭包。
    ///   不要在此方法中执行耗时操作（如文件 I/O、网络请求、复杂计算），
    ///   否则会阻塞整个编排器的状态访问。闭包内的逻辑不会在此处执行，仅被存储。
    static func register(in registry: OhPluginRegistry<Self>)

    /// 插件实例创建完成后的回调
    /// - 用于执行初始化逻辑，替代在 didFinishLaunching 中写逻辑
    /// - 注意：此方法执行时，插件实例已创建但尚未处理任何事件
    /// - Note: `@MainActor` 即契约：与 `init()` 一致，框架保证在主线程调用
    ///   （`Orchestrator.instantiatePlugin` 内部用 `DispatchQueue.main.sync` 兜底切主线程）。
    @MainActor func pluginDidResolve()
}

// MARK: - Default Implementation
public extension OhPlugin {
    static var id: String { String(describing: self) }
    static var priority: OhPriority { .medium }
    static var retention: OhRetentionPolicy { .destroy }
    static var isLazy: Bool { true }
    @MainActor func pluginDidResolve() {}
}

// MARK: - Concurrency Helper

/// 并发检查豁免盒：把非 Sendable 的值传递进主线程（`@MainActor`）隔离闭包。
///
/// **用途**：`OhSceneObserver.addScene` / `OhApplicationObserver.addApplication` 注册的
/// handler 需要在 `MainActor.assumeIsolated` 中驱动插件实例，但 `OhPlugin` 为简化使用者
/// 接入未约束 `Sendable`，编译期无法证明插件实例可跨隔离域传递。
///
/// **安全性依据**：插件实例的创建（`Orchestrator.instantiatePlugin`，内部用
/// `DispatchQueue.main.sync` 强制主线程）与事件驱动（UIKit 生命周期回调）都在主线程，
/// 实例实际是主线程独占的；这里只是把这一既有约定显式告知编译器。
///
/// - Warning: 仅用于上述场景；传入会被多线程并发访问的值会使豁免失效。
struct OhUncheckedSendable<T>: @unchecked Sendable {
    let value: T
}
