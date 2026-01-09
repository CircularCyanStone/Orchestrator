// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：定义生命周期服务的基础枚举与结构体类型，包括执行时机、优先级与驻留策略。

import Foundation

/// 应用生命周期事件（原 Phase）
/// - 标识一个特定的系统事件或自定义触发点
public struct OhEvent: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// 生命周期事件参数键名
public struct OhParameterKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

/// 服务优先级包装（可比较、可发送）
public struct OhPriority: RawRepresentable, Comparable, Sendable {
    /// 底层优先级数值（越大越先执行）
    public let rawValue: Int
    /// 以原始数值构造优先级
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static func < (lhs: OhPriority, rhs: OhPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    public static let low = OhPriority(rawValue: 250)
    public static let medium = OhPriority(rawValue: 500)
    public static let high = OhPriority(rawValue: 750)
    public static let critical = OhPriority(rawValue: 1000)
    /// 引导级别（最高优先级）
    /// - 适用于日志、Crash 监控等必须最早初始化的服务
    /// - 建议保持唯一性或极少量使用
    /// - 整个 App 应仅保留 1-2 个 Boot 级服务，且它们之间不应有依赖
    public static let boot = OhPriority(rawValue: Int.max)
}

/// 服务执行后的持有策略（字符串原始值，便于清单直接映射）
public enum OhRetentionPolicy: String, Sendable {
    /// 执行结束即释放，不被管理器持有
    case destroy
    /// 执行后被管理器以 `id` 持有，直至进程结束或手动清理
    case hold
}
