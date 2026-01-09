// Copyright © 2025 Coo. All rights reserved.
//
// 文件功能描述：实现 @OrchService 宏的具体逻辑，生成服务注册所需的代码。
// 类型功能描述：
// OhRegisterServiceMacro: 实现 MemberMacro 协议，解析被标记的类型（Struct/Class/Enum），
// 自动生成存储在 __DATA 段的 _coo_svc_entry 静态属性，用于运行时服务发现。

import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - Macros

/// 注册服务宏 (Member Macro)
public struct OhRegisterServiceMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        var typeName = ""
        
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            /// 判断当前声明的目标对象的类型，这里是struct
            typeName = structDecl.name.text
        } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
            /// 判断当前声明的目标对象的类型，这里是class
            typeName = classDecl.name.text
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            /// 判断当前声明的目标对象的类型，这里是enum
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
