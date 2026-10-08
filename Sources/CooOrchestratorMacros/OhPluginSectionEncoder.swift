// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：宏展开期把插件类名编码成 `__coo_sw_svc` Section 的定长整型字面量。
//
// - Note: 这是**唯一**的编码实现（库侧 `CooOrchestrator.OhPluginSectionDecoder` 只负责解码）。
//   宏 target 无法依赖库 target，且库要编译到 iOS 目标平台、宏只在 host 平台编译，
//   两侧不可能共享同一份代码；一致性由 `CooOrchestratorTests` 用硬编码黄金值 +
//   「宏展开产物 → 库侧解码」验证。
//
// ---------------------------------------------------------------------------
// 【为什么是整型字面量而不是 StaticString】
// Swift 6.3 起，带 `@section` 的静态量初始化器必须能被编译期**常量求值器**求值，
// 而求值器只支持标量常量。旧的 `(StaticString)` 形态会直接编译失败：
//   - Swift 6.4：error: unsupported type in a literal expression [const_unsupported_type]
//   - Swift 6.3：error: unsupported type in a constant expression
// 于是改为「类名 UTF-8 字节 → UInt64 字面量」的定长编码，运行时由库侧
// `CooOrchestrator.OhPluginSectionDecoder` 解码。
//
// 【编码规格】类名 UTF-8 字节 `b[i]` 装入：word[i / 8] |= UInt64(b[i]) << ((i % 8) * 8)
//             未使用字节为 0；单条目 = 8 × UInt64 = 64 字节；类名最长 64 字节。
//
// - Warning: 修改本文件的编码规则（含 `wordCount` / `maxClassNameByteCount` 等常量）时，
//   必须同步更新库侧解码器 `CooOrchestrator.OhPluginSectionDecoder` 与测试里的黄金值，
//   否则会出现「宏写进 Section、运行时读不出来」的静默故障。
// ---------------------------------------------------------------------------

import Foundation

/// `__coo_sw_svc` Section 条目的编码器（宏侧唯一职责）
///
/// - Note: 仅负责「类名 → 字面量源码」，不参与运行时解码。
public enum OhPluginSectionEncoder {

    // MARK: - Layout Constants

    /// 单个条目占用的 UInt64 数量（必须与库侧 `OhPluginSectionDecoder.wordCount` 一致）
    public static let wordCount = 8

    /// 类名 UTF-8 编码后的最大字节数（= 64，正好占满时不写 NUL 终止符）
    public static let maxClassNameByteCount = wordCount * 8

    /// Swift 元组类型源码，例如 `(UInt64, UInt64, ...)`（共 `wordCount` 个）
    public static let tupleTypeSource = "(" + Array(repeating: "UInt64", count: wordCount).joined(separator: ", ") + ")"

    // MARK: - Encoding

    /// 把类名编码成固定 `wordCount` 个 UInt64。
    ///
    /// - Parameter className: 完整限定类名（如 `SiKu.SKBootService`）
    /// - Returns: 编码结果；类名为空或 UTF-8 超过 `maxClassNameByteCount` 时返回 `nil`
    public static func encode(_ className: String) -> [UInt64]? {
        let bytes = Array(className.utf8)
        guard !bytes.isEmpty, bytes.count <= maxClassNameByteCount else { return nil }

        var words = [UInt64](repeating: 0, count: wordCount)
        for (index, byte) in bytes.enumerated() {
            // 每 8 个字节装入一个 UInt64，字节 i 占第 (i % 8) 个 8 位通道（小端）
            words[index / 8] |= UInt64(byte) << UInt64((index % 8) * 8)
        }
        return words
    }

    // MARK: - Source Rendering

    /// 生成元组字面量的 Swift 源码（供宏模板 `\(raw:)` 插值）。
    ///
    /// - Parameters:
    ///   - words: `encode(_:)` 的结果
    ///   - perLine: 每行渲染的字面量数量（仅影响生成代码的可读性）
    /// - Returns: 例如 `0x0000000000006563, 0x0000000000000000, ...`（按 `perLine` 换行）
    public static func literalSource(_ words: [UInt64], perLine: Int = 4) -> String {
        let literals = words.map(hexLiteral)

        var lines: [String] = []
        var index = 0
        while index < literals.count {
            let end = min(index + perLine, literals.count)
            lines.append("    " + literals[index..<end].joined(separator: ", "))
            index = end
        }
        return lines.joined(separator: ",\n")
    }

    /// 单个 `UInt64` 的定长十六进制字面量（16 位宽，便于人工核对黄金值）
    private static func hexLiteral(_ word: UInt64) -> String {
        let hex = String(word, radix: 16, uppercase: true)
        return "0x" + String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }
}
