// Copyright © 2025 Coo. All rights reserved.

/// 注册插件宏：零配置自动发现（写入 Mach-O Section）
///
/// 展开后向被标注的类型注入一个静态量（成员名固定为 `_coo_svc_entry`）：
///
/// ```swift
/// @used
/// @section("__DATA,__coo_sw_svc")
/// static let _coo_svc_entry: (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64) = (
///     0x424B532E754B6953, ...
/// )
/// ```
///
/// 运行时由 `OhSwiftSectionLoader` 扫描 `__DATA,__coo_sw_svc` 得到类名，再经
/// `NSClassFromString` 解析为类型，整个过程不需要 plist 或手动登记。
///
/// ## Swift 6.3+ 行为（重要）
///
/// Swift 6.3 起，带 `@section` 的静态量初始化器必须能被**编译期常量求值器**求值，
/// 而求值器只支持标量常量 —— 旧版本生成的 `(StaticString)` 形态会直接编译失败：
///
/// - Swift 6.4：`error: unsupported type in a literal expression [const_unsupported_type]`
/// - Swift 6.3：`error: unsupported type in a constant expression`
///
/// 因此本宏（v0.0.18 起）把类名的 UTF-8 字节编码成 8 个 `UInt64` 字面量
/// （单条目固定 64 字节），并使用 Swift ≥ 6.3 的稳定属性名 `@used` / `@section`：
///
/// - 使用方**不再需要** `-enable-experimental-feature SymbolLinkageMarkers`；
/// - 类名（`模块名.类型名`）UTF-8 编码后最长 64 字节，超出会得到明确的编译错误提示；
/// - 旧二进制（Swift ≤ 6.2 的宏产物）仍可被新版 `OhSwiftSectionLoader` 识别；
/// - 编码格式与解码实现见 `CooOrchestrator.OhPluginSectionDecoder`。
///
/// - Parameter moduleName: 可选的模块名称。如果不传，将尝试从文件路径推断
///   （跨模块场景建议显式指定，避免推断结果与真实模块名不一致）。
@attached(member, names: named(_coo_svc_entry))
public macro OrchPlugin(_ moduleName: String? = nil) = #externalMacro(module: "CooOrchestratorMacros", type: "OhRegisterPluginMacro")
