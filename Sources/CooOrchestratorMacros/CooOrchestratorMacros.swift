// Copyright © 2025 Coo. All rights reserved.

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

// MARK: - Debug Helper
// 用于在编译期输出日志，方便调试路径问题
struct DebugDiagnostic: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity
}

// MARK: - Helper

enum MacroHelper {
    /// 提取模块名称
    /// 策略：
    /// 1. 显式传参：@RegisterModule("MyModule")
    /// 2. 文件路径推断：从 Sources/{Module} 推断
    static func extractModuleName(
        from node: AttributeSyntax,
        in context: some MacroExpansionContext
    ) -> String {
        // 1. 尝试从参数获取
        if let args = node.arguments?.as(LabeledExprListSyntax.self),
           let first = args.first,
           let str = first.expression.as(StringLiteralExprSyntax.self) {
            let name = str.segments.first?.as(StringSegmentSyntax.self)?.content.text ?? ""
            if !name.isEmpty {
                return name
            }
        }
        
        // 2. 尝试从 location description 推断
        if let locationDescription = context.location(of: node)?.file.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text {
            // [Debug] 输出真实的 location description 到编译器警告中，方便查看
//            context.diagnose(Diagnostic(
//                node: node,
//                message: DebugDiagnostic(
//                    message: "🔍 [CooDebug] Real Location Description: \(locationDescription)",
//                    diagnosticID: MessageID(domain: "CooMacros", id: "path_debug"),
//                    severity: .warning
//                )
//            ))
            
            let inferredName = extractModuleNameFromLocation(locationDescription)
            if !inferredName.isEmpty {
                return inferredName
            }
        }
        
        // 3. 无法推断且未传参，抛出编译错误
        context.diagnose(Diagnostic(
            node: node,
            message: DebugDiagnostic(
                message: "❌ Unable to infer module name from context. Please specify the module name explicitly: @OrchService(\"YourModuleName\")",
                diagnosticID: MessageID(domain: "CooMacros", id: "module_inference_failed"),
                severity: .error
            )
        ))
        return ""
    }
    
    /// 从 location description 提取模块名
    /// 注意：这里的 path 通常不是文件系统路径，而是编译器提供的 location description (e.g. "ModuleName/FileName.swift")
    private static func extractModuleNameFromLocation(_ description: String) -> String {
        let components = description.split(separator: "/")
        
        // 直接使用第一部分作为模块名
        if let first = components.first, !first.isEmpty {
            // 如果第一部分是以 .swift 结尾（说明没有目录结构，只有文件名），则无法推断模块名
            if first.hasSuffix(".swift") {
                return ""
            }
            return String(first)
        }
        
        return ""
    }
}

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

@main
struct CooOrchestratorPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        OhRegisterServiceMacro.self
    ]
}
