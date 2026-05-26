# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

**CooOrchestrator** 是一个模块化应用生命周期与服务编排框架，通过统一的服务协议、事件驱动和优先级调度，实现模块的可插拔管理。

### 核心设计目标

1. **统一的服务协议** — 所有业务模块通过 `OhService` 协议接入生命周期
2. **时机 + 优先级调度** — 服务按优先级（boot > critical > high > medium > low）顺序执行
3. **多种自动注册机制** — 支持 Swift 宏、ObjC 宏、Plist 声明、Mach-O Section 扫描
4. **多线程安全** — 使用 `UnfairLock` 保护，支持并发分发
5. **责任链模式** — 服务可中断事件传播，返回结果给调用者

## 构建与测试

```bash
# SPM 构建
swift build

# SPM 测试
swift test

# 单个测试
swift test --filter CooOrchestratorTests.testExpansionLogic

# 通过 Xcode 工作区构建
open CooOrchestrator.xcodeproj
```

## 架构设计

### 核心组件

```
Orchestrator (单例调度器)
    │
    ├── OhService (服务协议)
    │     └── register(in:) → 注册感兴趣的事件
    │
    ├── OhRegistry<T> (泛型注册表)
    │     └── 收集事件处理闭包
    │
    ├── OhContext (执行上下文)
    │     └── event, source, args, parameters, userInfo
    │
    ├── OhResult (执行结果)
    │     └── .continue() / .stop(result:)
    │
    ├── OhServiceLoader (服务发现协议)
    │     └── 4 种实现：ManifestLoader, ModuleLoader, SwiftSectionLoader, ObjcSectionLoader
    │
    └── Loaders (服务发现)
          ├── OhManifestLoader → OhServices.plist
          ├── OhModuleLoader → OhModules.plist
          ├── OhSwiftSectionLoader → @OrchService 宏
          └── OhObjcSectionLoader → OC 宏
```

### 服务优先级

| 优先级 | 值 | 用途 |
|--------|-----|------|
| `.boot` | `Int.max` | 最高优先级，日志、Crash 监控等 |
| `.critical` | 1000 | 关键业务 |
| `.high` | 750 | 高优先级业务 |
| `.medium` | 500 | 默认优先级 |
| `.low` | 250 | 低优先级 |

### 驻留策略

| 策略 | 行为 |
|------|------|
| `.destroy` | 执行后立即释放（默认） |
| `.hold` | 保留实例，可通过 `Orchestrator.service(of:)` 获取 |

### 服务注册方式

#### 1. @OrchService 宏 (推荐)

```swift
@OrchService
final class MyService: OhService {
    static var priority: OhPriority = .high

    static func register(in registry: OhRegistry<MyService>) {
        registry.add(.didFinishLaunching) { service, ctx in
            // 处理启动逻辑
            return .continue()  // 或 .stop() 阻断后续
        }
    }
}
```

#### 2. OhModules.plist (纯代码)

```swift
// 1. 创建模块入口类
final class MyModule: OhServiceLoader {
    func load() -> [OhServiceDefinition] {
        [.service(MyService.self, priority: .high)]
    }
}

// 2. 在 OhModules.plist 注册模块类名
// <array>
//     <string>MyModule</string>
// </array>
```

#### 3. OhServices.plist (声明式)

```xml
<!-- Info.plist 或独立 OhServices.plist -->
<key>OhServices</key>
<array>
    <dict>
        <key>class</key><string>MyModule.MyService</string>
        <key>priority</key><integer>750</integer>
        <key>retention</key><string>hold</string>
        <key>args</key>
        <dict>
            <key>configKey</key><string>configValue</string>
        </dict>
    </dict>
</array>
```

#### 4. 工厂模式 (复杂初始化)

```swift
// 工厂类
final class MyServiceFactory: OhServiceFactory {
    init() {}
    func make(context: OhContext, args: [String: Sendable]) -> any OhService {
        let config = args["configKey"] as? String ?? ""
        return MyService(config: config)
    }
}

// OhServices.plist 中指定 factory
// <dict>
//     <key>class</key><string>MyModule.MyService</string>
//     <key>factory</key><string>MyModule.MyServiceFactory</string>
// </dict>
```

### 责任链控制

`OhResult` 控制事件传播：

```swift
// 继续执行后续服务
return .continue()

// 继续执行后续服务，带日志
return .continue(success: true, message: "操作完成")

// 中断传播，可返回结果给调用者
return .stop(result: .bool(true))

// 中断传播，带日志
return .stop(result: .void, success: true, message: "已处理")
```

### 预置观察者协议

#### OhApplicationObserver

处理 AppDelegate 生命周期事件：

- `.didFinishLaunching` — App 启动完成
- `.didBecomeActive` — App 进入活动状态
- `.willResignActive` — App 将要取消活动
- `.didEnterBackground` — App 进入后台
- `.willEnterForeground` — App 将要进入前台
- `.willTerminate` — App 将要终止
- `.didReceiveMemoryWarning` — 内存警告
- `.openURL` — 打开 URL
- `.continueUserActivity` — 继续用户活动
- `.performFetch` — 后台刷新
- `.didRegisterForRemoteNotifications` — 推送注册成功
- `.didReceiveRemoteNotification` — 收到推送
- `.configurationForConnecting` — 配置新 Scene
- `.didDiscardSceneSessions` — 丢弃 Scene

#### OhSceneObserver

处理 SceneDelegate 生命周期事件：

- `.sceneWillConnect` — Scene 连接
- `.sceneDidDisconnect` — Scene 断开
- `.sceneDidBecomeActive` — Scene 激活
- `.sceneWillResignActive` — Scene 取消激活
- `.sceneWillEnterForeground` — Scene 进入前台
- `.sceneDidEnterBackground` — Scene 进入后台
- `.sceneOpenURLContexts` — 打开 URL 上下文
- `.sceneContinueUserActivity` — 继续用户活动

### 集成 UIKit

#### AppDelegate

```swift
class AppDelegate: OhAppDelegate {
    override var serviceLoaders: [any OhServiceLoader] {
        [OhModuleLoader(), OhObjcSectionLoader()]
    }
}
```

#### SceneDelegate

```swift
class SceneDelegate: OhSceneDelegate {
    // 覆盖生命周期方法即可自动触发对应事件
}
```

#### 同时使用预置协议

```swift
@OrchService
final class MyService: OhService, OhApplicationObserver, OhSceneObserver {

    static func register(in registry: OhRegistry<MyService>) {
        addApplication(.didFinishLaunching, in: registry)
        addScene(.sceneWillConnect, in: registry)
    }

    // OhApplicationObserver
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?, context: OhContext) -> OhResult {
        // 处理启动
        return .continue()
    }

    // OhSceneObserver
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions, context: OhContext) -> OhResult {
        guard let windowScene = scene as? UIWindowScene else { return .continue() }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = ViewController()
        window.makeKeyAndVisible()
        return .stop()
    }
}
```

## 目录结构

```
Sources/
├── CooOrchestrator/                    # 主库
│   ├── Orchestrator.swift              # 核心调度器
│   ├── OhService.swift                 # 服务协议 + OhRegistry
│   ├── OhContext.swift                 # 执行上下文
│   ├── OhResult.swift                  # 执行结果枚举
│   ├── OhTypes.swift                   # OhEvent, OhPriority, OhRetentionPolicy
│   ├── OhServiceDefinition.swift       # 服务描述符 + OhServiceLoader 协议
│   ├── OhServiceFactory.swift          # 工厂协议
│   ├── OhLogger.swift                  # 日志系统
│   │
│   ├── delegates/                      # UIKit 代理基类
│   │   ├── OhAppDelegate.swift         # OhLegacyAppDelegate / OhAppDelegate
│   │   └── OhSceneDelegate.swift      # OhSceneDelegate
│   │
│   ├── standardEvents/                 # 预置事件与观察者
│   │   ├── OhStandardPhases.swift      # 自定义阶段事件
│   │   ├── OhAppDelegateEvents.swift   # AppDelegate 事件定义
│   │   ├── OhApplicationObserver.swift # AppDelegate 观察者协议
│   │   ├── OhSceneDelegateEvents.swift # SceneDelegate 事件定义
│   │   └── OhSceneObserver.swift       # SceneDelegate 观察者协议
│   │
│   ├── loaders/                        # 服务发现加载器
│   │   ├── OhManifestLoader.swift      # OhServices.plist 扫描
│   │   ├── OhModuleLoader.swift        # OhModules.plist 加载
│   │   ├── OhSwiftSectionLoader.swift  # Swift Mach-O Section
│   │   ├── OhObjcSectionLoader.swift   # ObjC Mach-O Section
│   │   └── SectionReader.swift         # Mach-O 读取工具
│   │
│   └── macros/
│       └── Macros.swift                # @OrchService 宏声明
│
└── CooOrchestratorMacros/              # 宏实现
    ├── Plugin.swift                    # 编译器插件入口
    ├── OhRegisterServiceMacro.swift    # @OrchService 实现
    └── MacroHelper.swift               # 宏辅助工具

Tests/CooOrchestratorTests/              # 单元测试
example/                                # 示例工程
SPMExample/                             # SPM 集成示例
```

## 并发模型

- Orchestrator 使用 `UnfairLock` 保护内部状态
- 服务实例化强制在主线程执行
- `fire()` 方法在调用者线程同步执行
- OhContext.UserInfo 使用锁保护，支持跨线程共享数据

## 日志系统

框架内置日志系统，默认开启：

```swift
// 关闭日志
OhLogger.isEnabled = false

// 日志自动记录：
// - 服务执行结果 (logTask)
// - 事件拦截 (logIntercept)
// - 性能耗时 (logPerf)
```
