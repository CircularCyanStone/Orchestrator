// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：定义服务执行结果与流程控制指令，以及系统代理方法的返回值封装。

import Foundation

/// 服务执行结果与流程控制
public enum OhResult: Sendable {
    /// 继续传播：当前服务执行完毕，继续执行后续优先级的服务
    /// - success: 服务本身执行是否成功
    /// - message: 可选的日志信息
    case `continue`(success: Bool = true, message: String? = nil)
    
    /// 中断传播：不再执行后续服务（独占处理）
    /// - result: 最终返回给系统的值（默认为 .void）
    /// - success: 服务本身执行是否成功
    /// - message: 可选的日志信息
    case stop(result: OhReturnValue = .void, success: Bool = true, message: String? = nil)
}

/// 系统代理方法的返回值封装
/// - Note: 标记为 @unchecked Sendable 以支持传递非 Sendable 的 UI 对象（如 UISceneConfiguration），
///         请开发者确保在正确的线程（通常是 MainActor）使用这些值。
public enum OhReturnValue: @unchecked Sendable {
    case void          // 无返回值
    case bool(Bool)    // 布尔返回值
    case any(Any)      // 通用返回值（需手动转换）
    
    /// 泛型提取辅助方法
    public func value<T>() -> T? {
        switch self {
        case .void:
            return nil
        case .bool(let b):
            return b as? T
        case .any(let v):
            return v as? T
        }
    }
}
