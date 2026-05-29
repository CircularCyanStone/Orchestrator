// Copyright © 2025 Coo. All rights reserved.
//
// 文件功能描述：实现 @OrchPlugin 宏的具体逻辑，生成插件注册所需的代码。

import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - Macros

/// 注册插件宏 (Member Macro)
public struct OhRegisterPluginMacro: MemberMacro {
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

        return [
            """
            @_used
            @_section("__DATA,__coo_sw_svc")
            static let _coo_svc_entry: (StaticString) = (
                "\(raw: finalName)"
            )
            """
        ]
    }
}
