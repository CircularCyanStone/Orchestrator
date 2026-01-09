// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：为需要复杂初始化的服务提供工厂协议与默认约定，支持从清单参数构建服务实例。
// 类型功能描述：OhServiceFactory 定义统一构造入口；默认要求可无参初始化，并通过 make(context:args:) 返回服务。

import Foundation

/// 服务工厂协议
/// - 适用场景：服务初始化需要外部依赖或复杂参数拼装时，通过工厂完成构造，
///   并由清单通过 `factory` 字段指定对应的工厂类型。
public protocol OhServiceFactory: AnyObject, Sendable {
    /// 要求可无参初始化，便于通过类名反射创建工厂实例
    init()
    /// 根据上下文与参数创建服务实例
    /// - Parameters:
    ///   - context: 运行上下文
    ///   - args: 清单透传的参数字典
    /// - Returns: 构造完成的服务实例
    func make(context: OhContext, args: [String: any Sendable]) -> any OhService
}
