// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：服务编排调度器，支持多线程安全分发，管理服务生命周期与日志。
// 类型功能描述：Orchestrator 作为单例管理器，维护服务注册表、常驻服务持有集合、调度入口 fire(_:) 与注册入口 register(_:)。
/**
 多线程方案选定策略：
 - 为了保证fire方法在传递事件时能保留原方法的执行环境，所以选择了传统的使用锁来保护多线程的访问安全。
 而使用Concurrency必然面临隔离域切换，一旦切换了就无法感知之前的执行环境了。
 */
import Foundation

/// 服务编排调度器 (Orchestrator)
/// - 职责：统一按“时机 + 优先级”顺序执行服务逻辑；支持责任链分发与流程控制。
/// - 并发模型：非隔离（Non-isolated），内部使用锁保护状态。fire 方法在调用者线程执行，支持同步返回值。
public final class Orchestrator: @unchecked Sendable {
    
    // 已经解析的服务条目
    private struct ResolvedServiceEntry: @unchecked Sendable {
        let desc: OhServiceDefinition
        let type: any OhService.Type
        let effEvent: OhEvent
        let effPriority: OhPriority
        let effResidency: OhRetentionPolicy
        
        // 绑定的处理器（从 Registry 获取）
        let handler: ((any OhService, OhContext) throws -> OhResult)?
    }
    
    /// 单例实例
    private static let shared = Orchestrator()
    
    /// 内部互斥锁，用于保护 descriptors, residentServices, cacheByPhase 等状态
    private let lock = UnfairLock()
    
    // MARK: - Internal Performance Helpers
    
    // 使用 String Key 以支持OhService.id 查询
    private typealias ServiceKey = String
    
    private init() {}
    
    // MARK: - Protected State (Must access via lock)
    
    /// 已注册的服务类 ID 集合（用于去重）
    private var registeredServiceIDs: Set<ObjectIdentifier> = []
    /// 常驻服务实例表 (Key改为 String)
    private var residentServices: [ServiceKey: any OhService] = [:]
    /// 记录是否完成服务的加载
    private var hasBootstrapped = false
    /// 全局配置源（用于懒加载一致性）
    private var loaders: [OhServiceLoader] = [OhManifestLoader(), OhModuleLoader()]
    /// 分组缓存
    private var cacheByEvent: [OhEvent: [ResolvedServiceEntry]] = [:]
    
    // MARK: - Private / Internal Implementation
    
    private func register(_ newDefinitions: [OhServiceDefinition]) {
        if newDefinitions.isEmpty { return }
        
        var eagerDefs: [OhServiceDefinition] = []
        
        // 仅在锁内进行元数据合并，获取需要急切加载的服务列表
        lock.lock()
        eagerDefs = self.mergeDefinitions(newDefinitions)
        lock.unlock()
        
        // 在锁外进行实例化，避免构造器/serviceDidResolve等外部函数重入造成死锁
        if !eagerDefs.isEmpty {
            self.instantiateEagerServices(eagerDefs)
        }
    }
    
    private func resolve(loaders: [OhServiceLoader]) {
        guard !hasBootstrapped else {
            /// 如果已经启动了，说明已经有某个线程启动成功了，可以直接返回。
            return
        }
        let start = CFAbsoluteTimeGetCurrent()
        var eagerDefs: [OhServiceDefinition] = []
        
        lock.lock()
        self.loaders = loaders
        if !hasBootstrapped {
            // 加载所有源 (使用 self.loaders)
            var allDefinitions: [OhServiceDefinition] = []
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
            self.instantiateEagerServices(eagerDefs)
        }
    }
    
    private func getService(of id: String) -> (any OhService)? {
        lock.lock()
        defer { lock.unlock() }
        return residentServices[id]
    }
    
    @discardableResult
    private func fire(
        _ event: OhEvent,
        source: Any? = nil,
        parameters: [OhParameterKey: Any] = [:]
    ) -> OhReturnValue {
        
        // 1. 引导加载与读取 (Lazy Bootstrap + Snapshot Read)
        // 使用快照模式：一次加锁，读取所有数据，后续循环无锁执行
        var entries: [ResolvedServiceEntry] = []
        var snapshotServices: [ServiceKey: any OhService] = [:]
        
        lock.lock()
        // 1.1 Bootstrap Check
        if !hasBootstrapped {
            // 加载所有源
            var allDefinitions: [OhServiceDefinition] = []
            for loader in loaders {
                allDefinitions.append(contentsOf: loader.load())
            }
            _ = mergeDefinitions(allDefinitions)
            hasBootstrapped = true
        }
        
        // 1.2 Read Entries
        entries = cacheByEvent[event] ?? []
        
        // 1.3 Snapshot Resident Services (避免循环内反复读锁)
        // 仅预加载本次事件需要的、且策略为 hold 的服务
        // 这里就是提前过滤掉一些和不包含当前event的服务,可以让循环里少一些。
        if !entries.isEmpty {
            for item in entries where item.effResidency == .hold {
                let key = item.type.id
                if let service = residentServices[key] {
                    /// hold 已构建的服务实例 --和-- 类型-key 建立映射
                    snapshotServices[key] = service
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
            
            // 实例化或获取服务实例
            // 优先使用快照中的实例，如果没有则尝试实例化
            var service: (any OhService)? = snapshotServices[item.type.id]
            
            if service == nil {
                // 快照未命中需要实例化
                service = resolveServiceInstance(for: item, context: context)
            }
            
            guard let validService = service else { continue }
            
            let start = CFAbsoluteTimeGetCurrent()
            var isSuccess = true
            var message: String? = nil
            var shouldStop = false
            
            // 执行服务（捕获异常）
            do {
                if let handler = item.handler {
                    let result = try handler(validService, context)
                    switch result {
                    case .continue(let s, let m):
                        isSuccess = s
                        message = m
                    case .stop(let r, let s, let m):
                        isSuccess = s
                        message = m
                        finalReturnValue = r
                        shouldStop = true
                        OhLogger.logIntercept(NSStringFromClass(item.desc.serviceClass), event: event)
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
                NSStringFromClass(item.desc.serviceClass),
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
    
    /// 解析服务实例（处理懒加载、缓存和锁）
    /// - Returns: 服务实例，如果解析失败则返回 nil
    private func resolveServiceInstance(for item: ResolvedServiceEntry, context: OhContext) -> (any OhService)? {
        let key = item.type.id
        
        // 1. 尝试从缓存获取 (Fast Path)
        if item.effResidency == .hold {
            lock.lock()
            if let existing = residentServices[key] {
                lock.unlock()
                return existing
            }
            lock.unlock()
        }
        
        // 2.因为强制在主线程实例化，所以这里不能在锁内，防止重入。
        guard let created = instantiateService(from: item.desc, context: context) else {
            return nil
        }
        
        // 3. 写入缓存 (Write Back)
        if case .hold = item.effResidency {
            lock.lock()
            // Double Check: 可能在实例化期间已有其他线程写入
            if let existing = residentServices[key] {
                lock.unlock()
                return existing
            } else {
                residentServices[key] = created
                lock.unlock()
                return created
            }
        }
        
        return created
    }
    
    // MARK: - Private Helper
    
    /// 实例化急切加载的服务
    /// - Note: 此方法内部保证在主线程执行实例化，并批量写入常驻服务表
    private func instantiateEagerServices(_ defs: [OhServiceDefinition]) {
        var createdServices: [ServiceKey: any OhService] = [:]
        
        for def in defs {
            // Context for eager load (no specific event)
            let context = OhContext(event: OhEvent(rawValue: "Orchestrator.EagerLoad"), args: def.args)
            
            // instantiateService 内部已处理主线程调度
            if let service = instantiateService(from: def, context: context) {
                if let serviceType = def.serviceClass as? any OhService.Type {
                    createdServices[serviceType.id] = service
                }
            }
        }
        
        if !createdServices.isEmpty {
            // 批量写入，减少锁粒度
            // 使用 lock 确保写入即生效，消除时序不一致
            // 安全性：因为 instantiateEagerServices 必须在锁外调用，所以此处 lock 是安全的
            lock.lock()
            for (key, service) in createdServices {
                if residentServices[key] == nil {
                    residentServices[key] = service
                }
            }
            lock.unlock()
        }
    }
    
    /// 实例化单个服务
    /// - Warning: **严禁在 isolationQueue.sync 闭包中调用此方法！**
    ///   此方法包含强制主线程执行的逻辑 (`DispatchQueue.main.sync`)。
    ///   如果在持有内部锁时同步等待主线程，极易引发死锁。
    private func instantiateService(
        from desc: OhServiceDefinition,
        context: OhContext
    ) -> (any OhService)? {
        // 强制主线程执行，确保 init 和 serviceDidResolve 在主线程
        if !Thread.isMainThread {
            return DispatchQueue.main.sync {
                instantiateService(from: desc, context: context)
            }
        }
        
        let className = NSStringFromClass(desc.serviceClass)
        var service: (any OhService)?
        
        // 优先使用工厂
        if let factoryType = desc.factoryClass as? OhServiceFactory.Type {
            OhLogger.log("Instantiate: Creating \(className) using factory \(NSStringFromClass(factoryType))", level: .debug)
            let factory = factoryType.init()
            service = factory.make(context: context, args: desc.args)
        } else if let serviceType = desc.serviceClass as? any OhService.Type {
            // 直接实例化
            OhLogger.log("Instantiate: Creating \(className) via init()", level: .debug)
            service = serviceType.init()
        } else {
            OhLogger.log("className \(desc.serviceClass) not implement OhService", level: .warning)
            return nil
        }
        
        // 触发初始化后回调
        service?.serviceDidResolve()
        
        return service
    }
    
    private func mergeDefinitions(_ items: [OhServiceDefinition]) -> [OhServiceDefinition] {
        let start = CFAbsoluteTimeGetCurrent()
        // 1. 批量解析类型，避免在循环中多次调用 NSClassFromString
        // 同时过滤掉已经注册过的类（假设类维度去重是业务需求）
        
        var entriesToInsert: [OhEvent: [ResolvedServiceEntry]] = [:]
        var eagerDefinitions: [OhServiceDefinition] = []
        
        // [Debug Log] 输出当前批次扫描到的所有类名
        OhLogger.log("MergeDefinitions: Received \(items.count) descriptors: \(items.map { NSStringFromClass($0.serviceClass) })", level: .debug)
        
        for d in items {
            guard let type = d.serviceClass as? any OhService.Type else { 
                OhLogger.log("MergeDefinitions: \(NSStringFromClass(d.serviceClass)) does not conform to OhService", level: .warning)
                continue
            }
            let typeID = ObjectIdentifier(type)
            
            // 快速去重检查 (No Lock, Caller holds lock)
            if registeredServiceIDs.contains(typeID) { 
                OhLogger.log("MergeDefinitions: Skipped duplicate service \(NSStringFromClass(type))", level: .debug)
                continue
            }
            
            // 标记已注册 (No Lock, Caller holds lock)
            registeredServiceIDs.insert(typeID)
            
            // Check Eager Loading
            // 只有当 isLazy == false 且 retention == .hold 时才进行急切加载
            let effectiveRetention = d.retentionPolicy ?? type.retention
            if !type.isLazy {
                if effectiveRetention == .hold {
                    eagerDefinitions.append(d)
                } else {
                    OhLogger.log("MergeDefinitions: Service \(NSStringFromClass(type)) is marked !isLazy but retention is .destroy. Fallback to lazy.", level: .warning)
                }
            }
            
            // 2. 收集服务里注册的事件和事件的Handlers
            // 这里会触发 invokeRegister -> T.register，这可能比较耗时且是纯计算/配置
            // 应该在锁外进行
            let handlers = collectHandlers(for: type)
            if handlers.isEmpty { 
                OhLogger.log("MergeDefinitions: \(NSStringFromClass(type)) has no handlers registered", level: .debug)
                continue
            }
            
            // 3. 内存聚合
            for (event, handler) in handlers {
                let entry = ResolvedServiceEntry(
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
        
        // 4. 批量合并到主缓存并排序 (No Lock, Caller holds lock)
        if !entriesToInsert.isEmpty {
            for (event, newEntries) in entriesToInsert {
                cacheByEvent[event, default: []].append(contentsOf: newEntries)
                // 原地排序，只对受影响的列表排序
                cacheByEvent[event]?.sort { $0.effPriority.rawValue > $1.effPriority.rawValue }
            }
        }
        
        let end = CFAbsoluteTimeGetCurrent()
        OhLogger.logPerf("MergeDefinitions: Processed \(items.count) items, Inserted \(entriesToInsert.count) groups. Cost: \(String(format: "%.4fs", end - start))")
        
        return eagerDefinitions
    }
    
    // 辅助：调用泛型静态方法 register
    private func collectHandlers(for type: any OhService.Type) -> [(OhEvent, (any OhService, OhContext) throws -> OhResult)] {
        return invokeRegister(type)
    }
    
    private func invokeRegister<T: OhService>(_ type: T.Type) -> [(OhEvent, (any OhService, OhContext) throws -> OhResult)] {
        let registry = OhRegistry<T>()
        T.register(in: registry)
        
        return registry.entries.map { entry in
            (entry.event, entry.handler)
        }
    }
}

extension Orchestrator {
    // MARK: - Public API
    
    /// 注册一批服务项
    /// - Parameter newDefinitions: 新增的服务描述符数组
    public static func register(_ newDefinitions: [OhServiceDefinition]) {
        shared.register(newDefinitions)
    }
    
    /// 便捷注册服务（类型安全）
    /// - Parameters:
    ///   - type: 服务类型
    ///   - priority: 覆盖默认优先级（可选）
    ///   - retention: 覆盖默认驻留策略（可选）
    ///   - args: 静态参数（可选）
    public static func register<T: OhService>(
        service type: T.Type,
        priority: OhPriority? = nil,
        retention: OhRetentionPolicy? = nil,
        args: [String: Sendable] = [:]
    ) {
        let desc = OhServiceDefinition(
            serviceClass: type,
            priority: priority,
            retentionPolicy: retention,
            args: args
        )
        shared.register([desc])
    }
    
    /// 启动引导：扫描并加载所有清单中的服务
    /// - Note: 建议在 didFinishLaunching 早期调用，防止被动懒加载导致的时序问题
    /// - Parameter loaders: 服务配置源列表（默认包含 Manifest 扫描和 Module 配置加载）
    public static func resolve(loaders: [OhServiceLoader] = [OhManifestLoader(), OhModuleLoader()]) {
        shared.resolve(loaders: loaders)
    }
    
    /// 触发指定时机的服务执行
    /// - Parameters:
    ///   - event: 执行时机
    ///   - source: 触发事件的源对象（如 AppDelegate, SceneDelegate），服务可尝试转型后修改其属性
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
    
    /// 触发服务执行并获取泛型返回值
    /// - Note: 这是 fire(_:environment:) 的便捷泛型封装
    @discardableResult
    public static func fire<T>(
        _ event: OhEvent,
        source: Any? = nil,
        parameters: [OhParameterKey: Any] = [:],
    ) -> T? {
        let ret = shared.fire(event, source: source, parameters: parameters)
        return ret.value()
    }
    
    /// 获取常驻服务实例
    /// - Parameter type: 服务类型
    /// - Returns: 如果该服务已被加载且策略为常驻 (.hold)，则返回实例；否则返回 nil
    public static func service<T: OhService>(of type: T.Type) -> T? {
        return shared.getService(of: type.id) as? T
    }
    
    /// 获取常驻服务实例（通过 ID）
    /// - Parameter id: 服务 ID
    /// - Returns: 如果该服务已被加载且策略为常驻 (.hold)，则返回实例；否则返回 nil
    public static func service(of id: String) -> (any OhService)? {
        return shared.getService(of: id)
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