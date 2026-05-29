// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：编排调度器，支持多线程安全分发，管理插件生命周期与日志。
// 类型功能描述：Orchestrator 作为单例管理器，维护插件注册表、常驻插件持有集合、调度入口 fire(_:) 与注册入口 register(_:)。
/**
 多线程方案选定策略：
 - 为了保证fire方法在传递事件时能保留原方法的执行环境，所以选择了传统的使用锁来保护多线程的访问安全。
 而使用Concurrency必然面临隔离域切换，一旦切换了就无法感知之前的执行环境了。
 */

// ============================================================================
// CooOrchestrator 能力边界
// ============================================================================
//
// **核心能力：生命周期编排**
//   - 按时机 (OhEvent) + 优先级 (OhPriority) 有序执行 Plugin 逻辑
//   - 支持责任链分发与流程控制 (continue / stop)
//   - 内置插件发现与加载 (Manifest / Module / Mach-O Section)
//
// **内置 Service Locator（简陋版 DI）**
//   - 通过 retention = .hold 保持插件实例存活
//   - 通过 Orchestrator.plugin(of:) / Orchestrator.service(of:) 获取实例
//   - 适合小型项目，无需引入外部 DI 工具
//
// **不负责的边界（应使用专业 DI 工具，如 Factory / Swinject）：**
//   - 复杂的依赖图解析（A 依赖 B，B 依赖 C）
//   - 构造器注入 / 属性注入
//   - 作用域管理（singleton / scoped / transient）
//   - 多模块间的业务服务注册与发现
//
// **命名约定：**
//   Plugin  → 编排流程中的功能单元（实现 OhPlugin，响应 OhEvent）
//   Service → 业务能力提供者（通过 DI 容器管理，命名为 XXXService）
//
// ============================================================================

import Foundation

/// 编排调度器 (Orchestrator)
/// - 职责：统一按"时机 + 优先级"顺序执行插件逻辑；支持责任链分发与流程控制。
/// - 并发模型：非隔离（Non-isolated），内部使用锁保护状态。fire 方法在调用者线程执行，支持同步返回值。
public final class Orchestrator: @unchecked Sendable {

    // 已经解析的插件条目
    private struct ResolvedPluginEntry: @unchecked Sendable {
        let desc: OhPluginDefinition
        let type: any OhPlugin.Type
        let effEvent: OhEvent
        let effPriority: OhPriority
        let effResidency: OhRetentionPolicy

        // 绑定的处理器（从 PluginRegistry 获取）
        let handler: ((any OhPlugin, OhContext) throws -> OhResult)?
    }

    /// 单例实例
    private static let shared = Orchestrator()

    /// 内部互斥锁，用于保护 descriptors, residentPlugins, cacheByPhase 等状态
    private let lock = UnfairLock()

    // MARK: - Internal Performance Helpers

    // 使用 String Key 以支持 OhPlugin.id 查询
    private typealias PluginKey = String

    private init() {}

    // MARK: - Protected State (Must access via lock)

    /// 已注册的插件类 ID 集合（用于去重）
    private var registeredPluginIDs: Set<ObjectIdentifier> = []
    /// 常驻插件实例表 (Key为 String)
    private var residentPlugins: [PluginKey: any OhPlugin] = [:]
    /// 记录是否完成插件的加载
    private var hasBootstrapped = false
    /// 全局配置源（用于懒加载一致性）
    private var loaders: [OhPluginLoader] = [OhManifestLoader(), OhModuleLoader()]
    /// 分组缓存
    private var cacheByEvent: [OhEvent: [ResolvedPluginEntry]] = [:]

    // MARK: - Private / Internal Implementation

    private func register(_ newDefinitions: [OhPluginDefinition]) {
        if newDefinitions.isEmpty { return }

        var eagerDefs: [OhPluginDefinition] = []

        // 仅在锁内进行元数据合并，获取需要急切加载的插件列表
        lock.lock()
        eagerDefs = self.mergeDefinitions(newDefinitions)
        lock.unlock()

        // 在锁外进行实例化，避免构造器/pluginDidResolve等外部函数重入造成死锁
        if !eagerDefs.isEmpty {
            self.instantiateEagerPlugins(eagerDefs)
        }
    }

    private func resolve(loaders: [OhPluginLoader]) {
        guard !hasBootstrapped else {
            /// 如果已经启动了，说明已经有某个线程启动成功了，可以直接返回。
            return
        }
        let start = CFAbsoluteTimeGetCurrent()
        var eagerDefs: [OhPluginDefinition] = []

        lock.lock()
        self.loaders = loaders
        if !hasBootstrapped {
            // 加载所有源 (使用 self.loaders)
            var allDefinitions: [OhPluginDefinition] = []
            for loader in self.loaders {
                allDefinitions.append(contentsOf: loader.load())
            }

            eagerDefs = mergeDefinitions(allDefinitions)
            hasBootstrapped = true

            let end = CFAbsoluteTimeGetCurrent()
            OhLogger.logPerf("Resolve: Bootstrap completed. Total Cost: \(String(format: "%.4fs", end - start))")
        }
        lock.unlock()

        if !eagerDefs.isEmpty {
            self.instantiateEagerPlugins(eagerDefs)
        }
    }

    private func getPlugin(of id: String) -> (any OhPlugin)? {
        lock.lock()
        defer { lock.unlock() }
        return residentPlugins[id]
    }

    @discardableResult
    private func fire(
        _ event: OhEvent,
        source: Any? = nil,
        parameters: [OhParameterKey: Any] = [:]
    ) -> OhReturnValue {

        // 1. 引导加载与读取 (Lazy Bootstrap + Snapshot Read)
        // 使用快照模式：一次加锁，读取所有数据，后续循环无锁执行
        var entries: [ResolvedPluginEntry] = []
        var snapshotPlugins: [PluginKey: any OhPlugin] = [:]

        lock.lock()
        // 1.1 Bootstrap Check
        if !hasBootstrapped {
            // 加载所有源
            var allDefinitions: [OhPluginDefinition] = []
            for loader in loaders {
                allDefinitions.append(contentsOf: loader.load())
            }
            _ = mergeDefinitions(allDefinitions)
            hasBootstrapped = true
        }

        // 1.2 Read Entries
        entries = cacheByEvent[event] ?? []

        // 1.3 Snapshot Resident Plugins (避免循环内反复读锁)
        // 仅预加载本次事件需要的、且策略为 hold 的插件
        if !entries.isEmpty {
            for item in entries where item.effResidency == .hold {
                let key = item.type.id
                if let plugin = residentPlugins[key] {
                    snapshotPlugins[key] = plugin
                }
            }
        }
        lock.unlock()

        // 2. 准备责任链环境
        let sharedUserInfo = OhContext.UserInfo()
        var finalReturnValue: OhReturnValue = .void

        // 3. 遍历执行（完全无锁，除非触发懒加载实例化写入）
        for item in entries {
            // 构造 Context
            let context = OhContext(
                event: event,
                source: source,
                args: item.desc.args,
                parameters: parameters,
                userInfo: sharedUserInfo
            )

            // 实例化或获取插件实例
            var plugin: (any OhPlugin)? = snapshotPlugins[item.type.id]

            if plugin == nil {
                plugin = resolvePluginInstance(for: item, context: context)
            }

            guard let validPlugin = plugin else { continue }

            let start = CFAbsoluteTimeGetCurrent()
            var isSuccess = true
            var message: String? = nil
            var shouldStop = false

            do {
                if let handler = item.handler {
                    let result = try handler(validPlugin, context)
                    switch result {
                    case .continue(let s, let m):
                        isSuccess = s
                        message = m
                    case .stop(let r, let s, let m):
                        isSuccess = s
                        message = m
                        finalReturnValue = r
                        shouldStop = true
                        OhLogger.logIntercept(NSStringFromClass(item.desc.pluginClass), event: event)
                    }
                } else {
                    isSuccess = false
                    message = "No handler registered for event \(event.rawValue)"
                }
            } catch {
                isSuccess = false
                message = "Exception: \(error)"
            }

            let end = CFAbsoluteTimeGetCurrent()
            OhLogger.logTask(
                NSStringFromClass(item.desc.pluginClass),
                event: item.effEvent,
                success: isSuccess,
                message: message,
                cost: end - start
            )

            if shouldStop {
                break
            }
        }
        return finalReturnValue
    }

    /// 解析插件实例（处理懒加载、缓存和锁）
    private func resolvePluginInstance(for item: ResolvedPluginEntry, context: OhContext) -> (any OhPlugin)? {
        let key = item.type.id

        // 1. 尝试从缓存获取 (Fast Path)
        if item.effResidency == .hold {
            lock.lock()
            if let existing = residentPlugins[key] {
                lock.unlock()
                return existing
            }
            lock.unlock()
        }

        // 2.因为强制在主线程实例化，所以这里不能在锁内，防止重入。
        guard let created = instantiatePlugin(from: item.desc, context: context) else {
            return nil
        }

        // 3. 写入缓存 (Write Back)
        if case .hold = item.effResidency {
            lock.lock()
            if let existing = residentPlugins[key] {
                lock.unlock()
                return existing
            } else {
                residentPlugins[key] = created
                lock.unlock()
                return created
            }
        }

        return created
    }

    // MARK: - Private Helper

    /// 实例化急切加载的插件
    /// - Note: 此方法内部保证在主线程执行实例化，并批量写入常驻插件表
    private func instantiateEagerPlugins(_ defs: [OhPluginDefinition]) {
        var createdPlugins: [PluginKey: any OhPlugin] = [:]

        for def in defs {
            let context = OhContext(event: OhEvent(rawValue: "Orchestrator.EagerLoad"), args: def.args)

            if let plugin = instantiatePlugin(from: def, context: context) {
                if let pluginType = def.pluginClass as? any OhPlugin.Type {
                    createdPlugins[pluginType.id] = plugin
                }
            }
        }

        if !createdPlugins.isEmpty {
            lock.lock()
            for (key, plugin) in createdPlugins {
                if residentPlugins[key] == nil {
                    residentPlugins[key] = plugin
                }
            }
            lock.unlock()
        }
    }

    /// 实例化单个插件
    /// - Warning: **严禁在持有内部锁时调用此方法！**
    ///   此方法包含强制主线程执行的逻辑 (`DispatchQueue.main.sync`)。
    ///   如果在持有内部锁时同步等待主线程，极易引发死锁。
    private func instantiatePlugin(
        from desc: OhPluginDefinition,
        context: OhContext
    ) -> (any OhPlugin)? {
        // 强制主线程执行，确保 init 和 pluginDidResolve 在主线程
        if !Thread.isMainThread {
            return DispatchQueue.main.sync {
                instantiatePlugin(from: desc, context: context)
            }
        }

        let className = NSStringFromClass(desc.pluginClass)
        var plugin: (any OhPlugin)?

        // 优先使用工厂
        if let factoryType = desc.factoryClass as? OhPluginFactory.Type {
            OhLogger.log("Instantiate: Creating \(className) using factory \(NSStringFromClass(factoryType))", level: .debug)
            let factory = factoryType.init()
            plugin = factory.make(context: context, args: desc.args)
        } else if let pluginType = desc.pluginClass as? any OhPlugin.Type {
            // 直接实例化
            OhLogger.log("Instantiate: Creating \(className) via init()", level: .debug)
            plugin = pluginType.init()
        } else {
            OhLogger.log("className \(desc.pluginClass) does not conform to OhPlugin", level: .warning)
            return nil
        }

        // 触发初始化后回调
        plugin?.pluginDidResolve()

        return plugin
    }

    /// 合并插件定义，多线程安全都是由工具内部调用方保证的，并且只在工具内部使用。
    /// - Note: 此方法在调用者持有的锁内执行。内部会调用 `collectHandlers` 触发用户实现的 `register(in:)`。
    ///   由于 `register` 的设计意图是轻量的事件闭包注册（数组追加，微秒级），
    ///   将其保留在锁内可以保持 merge 过程的原子性和代码清晰度。
    /// - Parameter items: 新传入的插件定义
    /// - Returns: 需要急切加载的插件描述符（isLazy=false 且 retention=hold）
    private func mergeDefinitions(_ items: [OhPluginDefinition]) -> [OhPluginDefinition] {
        let start = CFAbsoluteTimeGetCurrent()

        var entriesToInsert: [OhEvent: [ResolvedPluginEntry]] = [:]
        var eagerDefinitions: [OhPluginDefinition] = []

        OhLogger.log("MergeDefinitions: Received \(items.count) descriptors: \(items.map { NSStringFromClass($0.pluginClass) })", level: .debug)

        for d in items {
            guard let type = d.pluginClass as? any OhPlugin.Type else {
                OhLogger.log("MergeDefinitions: \(NSStringFromClass(d.pluginClass)) does not conform to OhPlugin", level: .warning)
                continue
            }
            let typeID = ObjectIdentifier(type)

            if registeredPluginIDs.contains(typeID) {
                OhLogger.log("MergeDefinitions: Skipped duplicate plugin \(NSStringFromClass(type))", level: .debug)
                continue
            }

            registeredPluginIDs.insert(typeID)

            let effectiveRetention = d.retentionPolicy ?? type.retention
            if !type.isLazy {
                if effectiveRetention == .hold {
                    eagerDefinitions.append(d)
                } else {
                    OhLogger.log("MergeDefinitions: Plugin \(NSStringFromClass(type)) is marked !isLazy but retention is .destroy. Fallback to lazy.", level: .warning)
                }
            }

            let handlers = collectHandlers(for: type)
            if handlers.isEmpty {
                OhLogger.log("MergeDefinitions: \(NSStringFromClass(type)) has no handlers registered", level: .debug)
                continue
            }

            for (event, handler) in handlers {
                let entry = ResolvedPluginEntry(
                    desc: d,
                    type: type,
                    effEvent: event,
                    effPriority: d.priority ?? type.priority,
                    effResidency: effectiveRetention,
                    handler: handler
                )
                entriesToInsert[event, default: []].append(entry)
            }
        }

        if !entriesToInsert.isEmpty {
            for (event, newEntries) in entriesToInsert {
                cacheByEvent[event, default: []].append(contentsOf: newEntries)
                cacheByEvent[event]?.sort { $0.effPriority.rawValue > $1.effPriority.rawValue }
            }
        }

        let end = CFAbsoluteTimeGetCurrent()
        OhLogger.logPerf("MergeDefinitions: Processed \(items.count) items, Inserted \(entriesToInsert.count) groups. Cost: \(String(format: "%.4fs", end - start))")

        return eagerDefinitions
    }

    // 辅助：调用泛型静态方法 register
    private func collectHandlers(for type: any OhPlugin.Type) -> [(OhEvent, (any OhPlugin, OhContext) throws -> OhResult)] {
        return invokeRegister(type)
    }

    private func invokeRegister<T: OhPlugin>(_ type: T.Type) -> [(OhEvent, (any OhPlugin, OhContext) throws -> OhResult)] {
        let registry = OhPluginRegistry<T>()
        T.register(in: registry)

        return registry.entries.map { entry in
            (entry.event, entry.handler)
        }
    }
}

// MARK: - Public API

extension Orchestrator {

    /// 注册一批插件
    /// - Parameter newDefinitions: 新增的插件描述符数组
    public static func register(_ newDefinitions: [OhPluginDefinition]) {
        shared.register(newDefinitions)
    }

    /// 便捷注册插件（类型安全）
    /// - Parameters:
    ///   - type: 插件类型
    ///   - priority: 覆盖默认优先级（可选）
    ///   - retention: 覆盖默认驻留策略（可选）
    ///   - args: 静态参数（可选）
    public static func register<T: OhPlugin>(
        plugin type: T.Type,
        priority: OhPriority? = nil,
        retention: OhRetentionPolicy? = nil,
        args: [String: Sendable] = [:]
    ) {
        let desc = OhPluginDefinition(
            pluginClass: type,
            priority: priority,
            retentionPolicy: retention,
            args: args
        )
        shared.register([desc])
    }

    /// 启动引导：扫描并加载所有清单中的插件
    /// - Note: 建议在 didFinishLaunching 早期调用，防止被动懒加载导致的时序问题
    /// - Parameter loaders: 插件配置源列表（默认包含 Manifest 扫描和 Module 配置加载）
    public static func resolve(loaders: [OhPluginLoader] = [OhManifestLoader(), OhModuleLoader()]) {
        shared.resolve(loaders: loaders)
    }

    /// 触发指定时机的插件执行
    /// - Parameters:
    ///   - event: 执行时机
    ///   - source: 触发事件的源对象（如 AppDelegate, SceneDelegate），插件可尝试转型后修改其属性
    ///   - parameters: 动态事件参数（如 application, launchOptions 等）
    /// - Returns: 最终的执行结果（如果被中断，则返回中断时的值；否则返回 .void）
    @discardableResult
    public static func fire(
        _ event: OhEvent,
        source: Any? = nil,
        parameters: [OhParameterKey: Any] = [:]
    ) -> OhReturnValue {
        return shared.fire(event, source: source, parameters: parameters)
    }

    /// 触发插件执行并获取泛型返回值
    @discardableResult
    public static func fire<T>(
        _ event: OhEvent,
        source: Any? = nil,
        parameters: [OhParameterKey: Any] = [:],
    ) -> T? {
        let ret = shared.fire(event, source: source, parameters: parameters)
        return ret.value()
    }

    // MARK: - Plugin Instance Query

    /// 获取常驻插件实例
    /// - Parameter type: 插件类型
    /// - Returns: 如果该插件已被加载且策略为常驻 (.hold)，则返回实例；否则返回 nil
    public static func plugin<T: OhPlugin>(of type: T.Type) -> T? {
        return shared.getPlugin(of: type.id) as? T
    }

    /// 获取常驻插件实例（通过 ID）
    /// - Parameter id: 插件 ID
    /// - Returns: 如果该插件已被加载且策略为常驻 (.hold)，则返回实例；否则返回 nil
    public static func plugin(of id: String) -> (any OhPlugin)? {
        return shared.getPlugin(of: id)
    }
}

// MARK: - Internal Performance Helpers

/// 高性能互斥锁封装 (os_unfair_lock)
/// - Note: 必须是引用类型 (Class) 以保证锁地址稳定
final class UnfairLock: @unchecked Sendable {
    private var _lock = os_unfair_lock()

    init() {}

    @inline(__always)
    func lock() {
        os_unfair_lock_lock(&_lock)
    }

    @inline(__always)
    func unlock() {
        os_unfair_lock_unlock(&_lock)
    }
}
