// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：OC 桥接层，将 OhReturnValue 包装为 OC 可用的 NSObject 子类。

import Foundation

/// OC 可用的执行结果包装
/// - 将 Swift 的 `OhReturnValue` 枚举展开为 OC 友好的属性
@objcMembers
public class OhObjcResult: NSObject {

    private let underlying: OhReturnValue

    /// 是否为无返回值
    public var isVoid: Bool {
        if case .void = underlying { return true }
        return false
    }

    /// 布尔返回值（非 bool 类型返回 NO）
    public var boolValue: Bool {
        if case .bool(let b) = underlying { return b }
        return false
    }

    /// 通用返回值（void 类型返回 nil）
    public var anyValue: Any? {
        if case .any(let v) = underlying { return v }
        return nil
    }

    init(_ value: OhReturnValue) {
        self.underlying = value
    }
}
