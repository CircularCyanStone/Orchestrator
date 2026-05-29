// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：为 String 提供 ObjC 桥接类型到 Swift 类型的便捷转换。

import Foundation

// MARK: - String → OhEvent / OhParameterKey 便捷转换

public extension String {
    /// 将 ObjC 事件名字符串转换为 Swift 的 `OhEvent`
    var ohEvent: OhEvent {
        OhEvent(rawValue: self)
    }

    /// 将 ObjC 参数 Key 字符串转换为 Swift 的 `OhParameterKey`
    var ohParameterKey: OhParameterKey {
        OhParameterKey(rawValue: self)
    }
}
