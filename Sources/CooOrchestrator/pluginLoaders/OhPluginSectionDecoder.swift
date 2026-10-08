// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：定义 `@OrchPlugin` 宏写入 Mach-O `__coo_sw_svc` Section 的定长编码格式，
//              并提供该格式的**解码**实现（纯函数，可单测）。
//
// - Note: 编码只有一份实现，在宏侧 `CooOrchestratorMacros.OhPluginSectionEncoder`。
//   宏 target 无法依赖库 target（依赖方向是 库 → 宏），且库要编译到 iOS 目标平台、
//   宏只在 host 平台编译，因此这里不重复实现编码；两端是否一致由单元测试用
//   「硬编码黄金值 + 宏展开产物 → 本类型解码」验证。
//
// ---------------------------------------------------------------------------
// 【Section 数据格式】
//
// Swift 6.3 起，带 `@section` 的静态量初始化器必须能被编译期常量求值器求值，
// 而求值器只支持标量常量 —— `StaticString` 形态的初始化器会直接编译失败。
// 因此 `@OrchPlugin` 改为把类名的 UTF-8 字节编码成定长整型字面量：
//
// - 每个条目 = 8 个 UInt64 = 64 字节；Section 总大小 = 条目数 × 64（无 padding）
// - 类名（如 "SiKu.SKBootService"）的 UTF-8 字节 `b[i]` 按小端填入：
//       word[i / 8] |= UInt64(b[i]) << ((i % 8) * 8)
// - 未使用的字节一律为 0（解码时截断到第一个 0x00）
// - 类名 UTF-8 最长 64 字节；正好占满 64 字节时不写 NUL 终止符（宏侧超出即编译报错）
//
// - Warning: 该格式与 0.0.17 及更早的产物（`StaticString` 布局）**不兼容**：
//   升级后必须重新编译所有含 `@OrchPlugin` 的模块（源码依赖的正常构建即是如此）。
// ---------------------------------------------------------------------------

import Foundation

/// `__coo_sw_svc` Section 条目的解码器（库侧唯一职责）
///
/// - 设计：全部为无状态纯函数，便于单元测试（黄金值 / 边界 / 损坏数据）。
///   编码由宏侧的 `CooOrchestratorMacros.OhPluginSectionEncoder` 负责，
///   两端一致性由 `CooOrchestratorTests` 用「宏展开产物 → 本类型解码」验证。
enum OhPluginSectionDecoder {

    // MARK: - Layout Constants

    /// 单个条目占用的 UInt64 数量
    static let wordCount = 8

    /// 单个条目的字节数（= 64），也是 `@section` 单条目的大小
    static let entrySize = wordCount * 8

    // MARK: - Decode

    /// 解码一个条目（`wordCount` 个 UInt64 → 类名）。
    ///
    /// - Parameter words: 单个条目的字面量（数量必须等于 `wordCount`）
    /// - Returns: 类名；条目全 0、UTF-8 非法或不符合类名形态时返回 `nil`
    static func decode(_ words: [UInt64]) -> String? {
        guard words.count == wordCount else { return nil }

        var bytes = [UInt8]()
        bytes.reserveCapacity(entrySize)
        for word in words {
            for shift in 0..<8 {
                bytes.append(UInt8(truncatingIfNeeded: word >> UInt64(shift * 8)))
            }
        }
        return decodeEntry(bytes)
    }

    /// 从 Section 原始字节解码所有条目。
    ///
    /// - 按 `entrySize` 切块逐个解码；尾部不足一个条目的残留字节、以及解不出合法类名的
    ///   条目都会被忽略 —— 单个异常块不会影响同一 Section 中的其它插件。
    /// - Parameter bytes: `__coo_sw_svc` Section 的原始字节
    /// - Returns: 解码出的类名（保持 Section 内的物理顺序）
    static func decodeClassNames(fromSectionBytes bytes: [UInt8]) -> [String] {
        var names: [String] = []
        var offset = 0
        while offset + entrySize <= bytes.count {
            if let name = decodeEntry(Array(bytes[offset..<(offset + entrySize)])) {
                names.append(name)
            }
            offset += entrySize
        }
        return names
    }

    // MARK: - Entry Decoding Helper

    /// 解码单个条目（严格校验，避免把非本框架写进该段的数据当成类名）
    private static func decodeEntry(_ bytes: [UInt8]) -> String? {
        guard bytes.count == entrySize else { return nil }

        let nameBytes: ArraySlice<UInt8>
        if let terminator = bytes.firstIndex(of: 0) {
            // 编码约定：未使用的字节全为 0
            guard bytes[terminator...].allSatisfy({ $0 == 0 }) else { return nil }
            nameBytes = bytes[..<terminator]
        } else {
            // 64 字节被类名正好占满
            nameBytes = bytes[...]
        }

        guard !nameBytes.isEmpty, let name = String(bytes: nameBytes, encoding: .utf8) else { return nil }
        return isPlausibleClassName(name) ? name : nil
    }

    /// 类名形态校验：首字符为字母或下划线，其余为字母 / 数字 / `_` / `.`
    private static func isPlausibleClassName(_ name: String) -> Bool {
        guard let first = name.first, first.isLetter || first == "_" else { return false }
        return name.allSatisfy { character in
            character == "_" || character == "." || character.isLetter || character.isNumber
        }
    }
}
