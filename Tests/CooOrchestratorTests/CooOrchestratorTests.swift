// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：CooOrchestrator 单元测试。
//
// 覆盖：
// 1. `__coo_sw_svc` **解码**（库侧 `OhPluginSectionDecoder`：纯函数 + 硬编码黄金值）
// 2. `__coo_sw_svc` **编码**（宏侧 `OhPluginSectionEncoder`；宏模块仅 host 平台可用）
// 3. `@OrchPlugin` 宏展开（生成代码的形态 / 诊断，且产物必须能被库侧解码）
// 4. 编译期真实使用（测试 target 内的 @OrchPlugin 声明即回归保护）

import Foundation
import XCTest
import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacros

@testable import CooOrchestrator

#if canImport(CooOrchestratorMacros)
    import CooOrchestratorMacros
#endif

// MARK: - 黄金值

/// `SiKu.SKBootService` 的黄金字面量：**编码（宏侧）与解码（库侧）都以它为准**。
///
/// 任何一端改动编码规则都会让这里的断言失败 —— 这就是「两端字节级一致」的守护方式。
enum SectionGoldenValue {
    /// 18 字节，占 3 个 UInt64，其余字节补 0
    static let className = "SiKu.SKBootService"

    static let words: [UInt64] = [
        0x424B532E754B6953, 0x6976726553746F6F, 0x0000000000006563,
        0x0000000000000000, 0x0000000000000000, 0x0000000000000000,
        0x0000000000000000, 0x0000000000000000
    ]
}

/// 把 `[UInt64]` 展开为小端字节序列（即 Section 中的实际排布）
private func bytes(of words: [UInt64]) -> [UInt8] {
    words.flatMap { word in
        (0..<8).map { UInt8(truncatingIfNeeded: word >> UInt64($0 * 8)) }
    }
}

// MARK: - 1. 解码（库侧，纯函数）

final class OhPluginSectionDecoderTests: XCTestCase {

    /// 布局常量（与宏侧 `OhPluginSectionEncoder` 的常量必须一致）
    func testLayoutConstants() {
        XCTAssertEqual(CooOrchestrator.OhPluginSectionDecoder.wordCount, 8)
        XCTAssertEqual(CooOrchestrator.OhPluginSectionDecoder.entrySize, 64)
    }

    /// 黄金值：字面量 → 类名
    func testGoldenValueDecodesToSiKuBootService() {
        XCTAssertEqual(
            CooOrchestrator.OhPluginSectionDecoder.decode(SectionGoldenValue.words),
            SectionGoldenValue.className
        )
    }

    /// 黄金值字节序：前 18 字节与类名 UTF-8 逐字节一致，其余全 0
    func testGoldenValueByteOrder() {
        let raw = bytes(of: SectionGoldenValue.words)
        XCTAssertEqual(raw.count, CooOrchestrator.OhPluginSectionDecoder.entrySize)
        XCTAssertEqual(
            Array(raw.prefix(SectionGoldenValue.className.utf8.count)),
            Array(SectionGoldenValue.className.utf8)
        )
        XCTAssertTrue(raw.dropFirst(SectionGoldenValue.className.utf8.count).allSatisfy { $0 == 0 })
    }

    /// 长度边界：63 字节（尾部 NUL）与 64 字节（正好占满、无 NUL 终止符）都能解码
    func testDecodeLengthBoundaries() {
        // "A" × 63，最后一个字节是 NUL 终止符
        var name63 = [UInt64](repeating: 0x4141414141414141, count: 8)
        name63[7] = 0x0041414141414141
        XCTAssertEqual(
            CooOrchestrator.OhPluginSectionDecoder.decode(name63),
            String(repeating: "A", count: 63)
        )

        // "B" × 64：正好占满，没有 NUL 终止符
        let name64 = [UInt64](repeating: 0x4242424242424242, count: 8)
        XCTAssertEqual(
            CooOrchestrator.OhPluginSectionDecoder.decode(name64),
            String(repeating: "B", count: 64)
        )
    }

    /// 非法输入：元素个数不符 / 全 0 条目 / 非类名形态 / NUL 之后仍有非 0
    func testInvalidEntriesDecodeToNil() {
        XCTAssertNil(CooOrchestrator.OhPluginSectionDecoder.decode([0, 0]))
        XCTAssertNil(CooOrchestrator.OhPluginSectionDecoder.decode([UInt64](repeating: 0, count: 8)))
        // 首字符不是字母/下划线（旧格式二进制数据的典型特征）
        XCTAssertNil(CooOrchestrator.OhPluginSectionDecoder.decode([0x00_00_00_00_00_00_2E_31, 0, 0, 0, 0, 0, 0, 0]))
        // NUL 之后仍有非 0 字节（违反「未使用字节为 0」约定）
        XCTAssertNil(CooOrchestrator.OhPluginSectionDecoder.decode([0x41, 0x42, 0, 0x43, 0, 0, 0, 0]))
    }

    /// 多条目字节流解码（loader 实际使用的入口）
    func testDecodeClassNamesFromSectionBytes() {
        let second: [UInt64] = [0x0000000000422E41, 0, 0, 0, 0, 0, 0, 0] // "A.B"
        let raw = bytes(of: SectionGoldenValue.words) + bytes(of: second)
        XCTAssertEqual(raw.count, 2 * CooOrchestrator.OhPluginSectionDecoder.entrySize)
        XCTAssertEqual(
            CooOrchestrator.OhPluginSectionDecoder.decodeClassNames(fromSectionBytes: raw),
            ["SiKu.SKBootService", "A.B"]
        )

        // 尾部不足一个条目的残留字节被忽略
        XCTAssertEqual(
            CooOrchestrator.OhPluginSectionDecoder.decodeClassNames(fromSectionBytes: raw + [0x01, 0x02, 0x03]),
            ["SiKu.SKBootService", "A.B"]
        )
        // 空 section
        XCTAssertTrue(CooOrchestrator.OhPluginSectionDecoder.decodeClassNames(fromSectionBytes: []).isEmpty)
        // 损坏的条目被跳过，不影响同一 Section 里的其它插件
        var corrupted = raw
        corrupted[100] = 0x7A // 落在第二个条目的 NUL 填充区
        XCTAssertEqual(
            CooOrchestrator.OhPluginSectionDecoder.decodeClassNames(fromSectionBytes: corrupted),
            ["SiKu.SKBootService"]
        )
    }
}

// MARK: - 2. 编码（宏侧实现；宏模块只在 host 平台可用）

#if canImport(CooOrchestratorMacros)
final class OhPluginSectionEncoderTests: XCTestCase {

    /// 编码黄金值：宏侧编码结果必须逐位等于黄金字面量
    func testEncodeMatchesGoldenValue() {
        XCTAssertEqual(
            CooOrchestratorMacros.OhPluginSectionEncoder.encode(SectionGoldenValue.className),
            SectionGoldenValue.words
        )
    }

    /// 往返：宏侧 encode → 库侧 decode（真实形态的类名：模块限定名 / 单段名 / Unicode / 1 字节名）
    func testRoundTripThroughDecoder() {
        let names = [
            "SiKu.SKBootService",
            "CooOrchestratorTests.LoaderProbePlugin",
            "A.B",
            "Module.类名",
            "S"
        ]

        for name in names {
            guard let words = CooOrchestratorMacros.OhPluginSectionEncoder.encode(name) else {
                XCTFail("encode 意外返回 nil: \(name)")
                continue
            }
            XCTAssertEqual(words.count, CooOrchestratorMacros.OhPluginSectionEncoder.wordCount)
            XCTAssertEqual(CooOrchestrator.OhPluginSectionDecoder.decode(words), name)
        }
    }

    /// 编码长度边界：63 / 64 字节合法（64 字节正好占满），65 字节与空串返回 nil
    func testEncodeLengthBoundaries() {
        XCTAssertEqual(CooOrchestratorMacros.OhPluginSectionEncoder.wordCount, 8)
        XCTAssertEqual(CooOrchestratorMacros.OhPluginSectionEncoder.maxClassNameByteCount, 64)

        XCTAssertNotNil(CooOrchestratorMacros.OhPluginSectionEncoder.encode(String(repeating: "A", count: 63)))
        XCTAssertNotNil(CooOrchestratorMacros.OhPluginSectionEncoder.encode(String(repeating: "B", count: 64)))
        XCTAssertNil(CooOrchestratorMacros.OhPluginSectionEncoder.encode(String(repeating: "C", count: 65)))
        XCTAssertNil(CooOrchestratorMacros.OhPluginSectionEncoder.encode(""))
    }
}
#endif

// MARK: - 3. @OrchPlugin 宏展开

final class OhRegisterPluginMacroTests: XCTestCase {

    /// 宏展开产物必须能被**库侧解码器**还原 —— 两端字节级一致的直接证据
    func testMacroExpansionAgreesWithLibraryDecoder() throws {
        let (text, context) = try expandMembers(
            """
            @OrchPlugin("TestModule")
            final class TestPluginA {}
            """
        )

        XCTAssertTrue(context.diagnostics.isEmpty, "不应产生诊断: \(context.diagnostics.map { $0.message })")

        XCTAssertTrue(text.contains("@used"), "宏必须使用新属性名 @used（旧名 @_used 在 6.3+ 会警告）:\n\(text)")
        XCTAssertTrue(text.contains("@section(\"__DATA,__coo_sw_svc\")"), "宏必须写入 __coo_sw_svc section:\n\(text)")
        XCTAssertTrue(
            text.contains("static let _coo_svc_entry: (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64) = ("),
            "成员名与类型必须与 Macros.swift / 库侧布局一致:\n\(text)"
        )

        let words = Self.uint64Literals(in: text)
        XCTAssertEqual(words.count, CooOrchestrator.OhPluginSectionDecoder.wordCount)
        XCTAssertEqual(CooOrchestrator.OhPluginSectionDecoder.decode(words), "TestModule.TestPluginA")
    }

    /// 黄金值：宏对 `SiKu.SKBootService` 生成的 8 个字面量必须逐位等于黄金字面量
    func testMacroGoldenValueMatchesGoldenWords() throws {
        let (text, context) = try expandMembers(
            """
            @OrchPlugin("SiKu")
            final class SKBootService {}
            """
        )
        XCTAssertTrue(context.diagnostics.isEmpty)
        XCTAssertEqual(Self.uint64Literals(in: text), SectionGoldenValue.words)
    }

    /// 超长类名：给出可读的编译错误，且不生成任何成员
    func testTooLongClassNameDiagnostic() throws {
        let longName = String(repeating: "VeryLongClassName", count: 5) // 85 字节 + "M." = 87
        let (text, context) = try expandMembers(
            """
            @OrchPlugin("M")
            final class \(longName) {}
            """
        )

        XCTAssertEqual(text, "", "超长时不应生成任何成员")
        XCTAssertEqual(context.diagnostics.count, 1)
        XCTAssertEqual(context.diagnostics.first?.diagMessage.severity, .error)
        XCTAssertEqual(context.diagnostics.first?.diagMessage.diagnosticID, MessageID(domain: "CooMacros", id: "plugin_class_name_too_long"))
        XCTAssertTrue(context.diagnostics.first?.message.contains("64 字节") == true)
    }

    // MARK: Helpers

    /// 解析源码并调用宏展开，返回（成员源码文本, 展开上下文）
    private func expandMembers(
        _ source: String
    ) throws -> (text: String, context: TestMacroExpansionContext) {
#if canImport(CooOrchestratorMacros)
        let file = Parser.parse(source: source)
        let classDecl = try XCTUnwrap(file.statements.first?.item.as(ClassDeclSyntax.self))
        let attribute = try XCTUnwrap(classDecl.attributes.first?.as(AttributeSyntax.self))

        let context = TestMacroExpansionContext()
        let members = try OhRegisterPluginMacro.expansion(
            of: attribute,
            providingMembersOf: classDecl,
            conformingTo: [],
            in: context
        )
        return (members.map(\.description).joined(separator: "\n"), context)
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    /// 从宏生成源码中提取 `0x...` 字面量（顺序即元组顺序）
    private static func uint64Literals(in text: String) -> [UInt64] {
        text.split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("0x") }
            .compactMap { UInt64($0.dropFirst(2), radix: 16) }
    }
}

/// 测试用宏展开上下文：只实现 `@OrchPlugin` 展开实际用到的最小能力
/// （收集诊断；本宏不使用唯一名生成，也不依赖源码位置）
///
/// - Note: 自行实现而不是用 `BasicMacroExpansionContext`（位于 `SwiftSyntaxMacroExpansion`），
///   以免为一个测试向 Package.swift 增加新的 product 依赖。
final class TestMacroExpansionContext: MacroExpansionContext {
    private(set) var diagnostics: [Diagnostic] = []
    var lexicalContext: [Syntax] = []
    private var uniqueNameIndex = 0

    func makeUniqueName(_ name: String) -> TokenSyntax {
        uniqueNameIndex += 1
        return TokenSyntax.identifier("\(name)_\(uniqueNameIndex)")
    }

    func diagnose(_ diagnostic: Diagnostic) {
        diagnostics.append(diagnostic)
    }

    func location(
        of node: some SyntaxProtocol,
        at position: PositionInSyntaxNode,
        filePathMode: SourceLocationFilePathMode
    ) -> AbstractSourceLocation? {
        nil
    }
}

// MARK: - 4. 编译期真实使用（回归保护）

/// 测试用插件：实现 `OhPlugin` 并继承 `NSObject`，以便 `NSClassFromString`
/// 能在 ObjC 运行时里解析到它（与使用方插件形态一致）。
///
/// - Note: 该声明的存在即回归保护 —— 测试 target 编译时宏会被真实展开，
///   宏一旦生成非法代码（例如退回 `(StaticString)` 那套），测试 target 直接编译失败。
///   运行时的「Section → load() 发现 → NSClassFromString 解析 → 收到事件」链路
///   由独立宿主验证（`swift test` 下 `Bundle.main` 指向 xctest runner，
///   `SectionReader` 的「仅扫描主 Bundle」过滤不会命中测试可执行文件）。
@OrchPlugin("CooOrchestratorTests")
final class LoaderProbePlugin: NSObject, OhPlugin {
    @MainActor override init() { super.init() }

    static func register(in registry: OhPluginRegistry<LoaderProbePlugin>) {
        registry.add(.didFinishLaunching) { _, _ in
            .continue()
        }
    }
}
