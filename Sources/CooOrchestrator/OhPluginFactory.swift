// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：为需要复杂初始化的插件提供工厂协议与默认约定，支持从清单参数构建插件实例。

import Foundation

/// 插件工厂协议
/// - 适用场景：插件初始化需要外部依赖或复杂参数拼装时，通过工厂完成构造，
///   并由清单通过 `factory` 字段指定对应的工厂类型。
public protocol OhPluginFactory: AnyObject {
    /// 要求可无参初始化，便于通过类名反射创建工厂实例
    /// - Note: `@MainActor` 即契约：框架在调用前已切到主线程
    ///   （`Orchestrator.instantiateOnMain`），实现方不需要自行调度
    ///   （可写非隔离方法，也可写 `@MainActor` 方法）。
    @MainActor init()
    /// 根据上下文与参数创建插件实例
    /// - Parameters:
    ///   - context: 运行上下文
    ///   - args: 清单透传的参数字典
    /// - Returns: 构造完成的插件实例
    /// - Note: `@MainActor` 即契约：与 `OhPlugin.init()` / `pluginDidResolve()` 一致，
    ///   工厂的构造与 `make` 都在主线程完成。
    @MainActor func make(context: OhContext, args: [String: any Sendable]) -> any OhPlugin
}
