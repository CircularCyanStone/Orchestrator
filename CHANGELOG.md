# Changelog

本文件记录 CooOrchestrator 的版本变更。历史条目可结合 `git log` 查阅。

## [0.0.18] - 2026-10-08

### 修复

- **`@OrchPlugin` 在 Swift 6.3+ 无法编译（包级缺陷，不是使用方用法问题）。**
  Swift 6.3 起，带 `@section` 的静态量初始化器必须能被**编译期常量求值器**求值，
  而求值器只支持标量常量，旧的 `(StaticString)` 形态因此在 6.3 / 6.4 上直接报错：

  | 工具链 | 报错 |
  |--------|------|
  | Swift 6.4（Xcode 27） | `error: unsupported type in a literal expression [const_unsupported_type]` |
  | Swift 6.3（Xcode 26.6） | `error: unsupported type in a constant expression` |

### 变更（`__DATA,__coo_sw_svc` 的数据格式，段名/节名不变）

- 宏改为生成 `@used` + `@section("__DATA,__coo_sw_svc")` + 8 个 `UInt64` 整型字面量：
  类名 UTF-8 字节 `b[i]` 装入 `word[i / 8] |= UInt64(b[i]) << ((i % 8) * 8)`（小端），
  单条目定长 64 字节，未用字节为 0。
  - **数据格式变化**：由 `StaticString` 结构体改为定长整型编码，**与 0.0.17 及更早的产物不兼容**。
  - **公开 API 全部兼容**：`@OrchPlugin`、`OhPlugin`、`OhPluginLoader`、`OhSwiftSectionLoader`
    签名与用法均未变，使用方只需升级依赖版本。
- 属性名由实验名 `@_used` / `@_section` 改为稳定名 `@used` / `@section`：
  - 不再需要 `-enable-experimental-feature SymbolLinkageMarkers`（`Package.swift` 中已移除）。
  - **使用 `@OrchPlugin` 的工程需要 Swift 6.3+ 工具链**（旧工具链没有 `@used` / `@section`）。
- 类名（`模块名.类型名`）UTF-8 超过 64 字节时，宏直接给出可读的编译错误，
  不再让使用者面对 `const_unsupported_type` 之类的晦涩报错。

### 新增

- `OhPluginSectionEncoder`（宏侧）：**唯一**的编码实现 —— 类名 → 8 × `UInt64` 字面量 + 生成源码渲染。
- `OhPluginSectionDecoder`（库侧）：解码纯函数（64 字节定长条目 → 类名）。
  - 编码**不重复实现**：宏 target 与库 target 无法共享代码（依赖方向是 库 → 宏，
    且库编译到 iOS 目标平台、宏只在 host 平台编译）。两端一致性由
    「硬编码黄金值 + 宏展开产物 → 库侧解码」的单元测试守护。
- 单元测试（12 项）：黄金值（编码侧逐位比对 + 解码侧还原）、63/64/65 字节边界、非法条目、
  多条目字节流解码与损坏条目跳过、宏展开产物可被库侧解码、超长类名诊断。

### 兼容性

- **需要重新编译**：本次改变了 `__coo_sw_svc` 的数据格式，升级后必须重新编译所有含
  `@OrchPlugin` 的模块（源码依赖的正常构建即是如此）；0.0.17 及更早、或 Swift ≤ 6.2
  编译出的产物不会被识别（不保留旧的 `StaticString` 读取路径）。
- macOS 上 `swift build` / `swift test` 恢复可用：`delegates/OhAppDelegate.swift`、
  `delegates/OhSceneDelegate.swift` 补齐 `#if canImport(UIKit)`（iOS 行为不变）。
- ObjC 路径未改动：`OhRegistrationMacros.h`、`__coo_svc` 段、`OhObjcSectionLoader`、
  `CooOrchestrator.podspec` 的 CocoaPods 排除配置保持原样。

### 验证结论（工具链 + 命令）

- **Swift 6.4（Xcode 27）与 Swift 6.3.3（Xcode 26.6）**：
  用宏真实展开产物做的 `swiftc -typecheck` 在两套工具链上均零诊断（带 / 不带
  `-enable-experimental-feature SymbolLinkageMarkers` 都是零诊断）。
- **`swift test`**：`Executed 12 tests, with 0 failures`。
- **端到端最小宿主**：`OhSwiftSectionLoader().load()` 发现插件（1 个）→
  `NSClassFromString` 解析成功（`host_probe.HostProbePlugin`）→
  `Orchestrator.fire(.didFinishLaunching)` 触发插件闭包；
  `otool -l` 确认 `(__DATA,__coo_sw_svc)` 的 `size = 0x40`（= 64 字节/条目）、`align 2^3 (8)`，
  原始字节与编码规范逐字节一致。

## [0.0.17] 及更早

历史记录见 `git log`。
