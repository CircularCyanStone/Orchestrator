// Copyright © 2025 Coo. All rights reserved.
//
// 文件功能描述：提供宏实现所需的辅助工具和调试诊断信息结构。
// 类型功能描述：
// DebugDiagnostic: 用于构建编译器诊断消息（错误、警告等）。
// MacroHelper: 提供从 AST 节点提取模块名称等辅助功能，支持从参数或文件路径推断模块名。

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

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
                message: "❌ Unable to infer module name from context. Please specify the module name explicitly: @OrchPlugin(\"YourModuleName\")",
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
