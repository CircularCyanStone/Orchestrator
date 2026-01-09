// Copyright © 2025 Coo. All rights reserved.
//
// 文件功能描述：Swift 宏插件的入口点，定义了该插件提供的所有宏。
// 类型功能描述：
// CooOrchestratorPlugin: 符合 CompilerPlugin 协议，注册 OhRegisterServiceMacro。
// 注意：此文件应尽可能保持精简，避免包含具体的宏实现逻辑，以确保编译器插件能被正确加载。

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
public struct CooOrchestratorPlugin: CompilerPlugin {
    public let providingMacros: [Macro.Type] = [
        OhRegisterServiceMacro.self
    ]
    
    public init() {}
}
