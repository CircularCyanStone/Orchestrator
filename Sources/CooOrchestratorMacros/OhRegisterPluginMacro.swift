// Copyright © 2025 Coo. All rights reserved.
//
// 文件功能描述：实现 @OrchPlugin 宏的具体逻辑，生成插件注册所需的代码。
//
// ---------------------------------------------------------------------------
// 【生成策略（Swift ≥ 6.3）】
// Swift 6.3 起，带 @section 的静态量初始化器必须能被编译期常量求值器求值，
// 求值器只支持标量常量，旧的 `(StaticString)` 形态会直接编译失败：
//   - Swift 6.4：error: unsupported type in a literal expression [const_unsupported_type]
//   - Swift 6.3：error: unsupported type in a constant expression
// 因此这里改为生成 8 个 UInt64 的整型字面量，把类名的 UTF-8 字节编码进
// `__DATA,__coo_sw_svc` Section，运行时由库侧 `OhPluginSectionDecoder` 解码。
//
// 生成的代码形如：
//     @used
//     @section("__DATA,__coo_sw_svc")
//     static let _coo_svc_entry: (UInt64, UInt64, ... , UInt64) = (
//         0x424B532E754B6953, 0x6976726553746F6F, 0x0000000000006563, 0x0000000000000000,
//         ...
//     )
// ---------------------------------------------------------------------------

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

// MARK: - Macros

/// 注册插件宏 (Member Macro)
public struct OhRegisterPluginMacro: MemberMacro {

    /// Section 属性参数（段名,节名），与库侧 `OhSwiftSectionLoader.sectionPlugin` 对应
    private static let sectionAttribute = "__DATA,__coo_sw_svc"

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        var typeName = ""

        if let structDecl = declaration.as(StructDeclSyntax.self) {
            typeName = structDecl.name.text
        } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
            typeName = classDecl.name.text
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            typeName = enumDecl.name.text
        } else {
            return []
        }
        let moduleName = MacroHelper.extractModuleName(from: node, in: context)

        let finalName = moduleName.isEmpty ? typeName : "\(moduleName).\(typeName)"

        guard let words = OhPluginSectionEncoder.encode(finalName) else {
            // 类名超出 Section 单条目容量：直接给出可读的编译错误，
            // 而不是让使用者面对常量求值器晦涩的报错
            context.diagnose(Diagnostic(
                node: node,
                message: DebugDiagnostic(
                    message: """
                        ❌ @OrchPlugin 无法注册 "\(finalName)"：类名 UTF-8 编码后为 \(finalName.utf8.count) 字节，\
                        超过 \(Self.sectionAttribute) section 单条目上限 \(OhPluginSectionEncoder.maxClassNameByteCount) 字节。\
                        请缩短模块名或类名（也可为 @OrchPlugin 传入更短的模块名）后重试。
                        """,
                    diagnosticID: MessageID(domain: "CooMacros", id: "plugin_class_name_too_long"),
                    severity: .error
                )
            ))
            return []
        }

        return [
            """
            @used
            @section("\(raw: Self.sectionAttribute)")
            static let _coo_svc_entry: \(raw: OhPluginSectionEncoder.tupleTypeSource) = (
            \(raw: OhPluginSectionEncoder.literalSource(words))
            )
            """
        ]
    }
}
