// Copyright © 2025 Coo. All rights reserved.

/// 注册服务宏
/// - Parameter moduleName: 可选的模块名称。如果不传，将尝试从文件路径推断。
@attached(member, names: named(_coo_svc_entry))
public macro OrchService(_ moduleName: String? = nil) = #externalMacro(module: "CooOrchestratorMacros", type: "OhRegisterServiceMacro")
