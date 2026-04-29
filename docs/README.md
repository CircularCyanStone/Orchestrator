# CooOrchestrator 使用指南

## 目录

1. [核心角色与职责](#1-核心角色与职责)
2. [四类协议的实现者](#2-四类协议的实现者)
3. [三种配置文件详解](#3-三种配置文件详解)
4. [四种服务注册方案](#4-四种服务注册方案)
5. [事件系统](#5-事件系统)
6. [优先级与驻留策略](#6-优先级与驻留策略)
7. [预置观察者协议](#7-预置观察者协议)
8. [UIKit 集成](#8-uikit-集成)
9. [完整使用示例](#9-完整使用示例)

---

## 1. 核心角色与职责

CooOrchestrator 框架中有 **四类协议**，每类协议由不同的角色实现：

| 协议 | 实现者 | 框架职责 |
|------|--------|----------|
| `OhService` | **业务开发者** | 定义业务模块的入口点 |
| `OhServiceLoader` | **框架内置 / 业务开发者** | 发现并加载服务描述符 |
| `OhModuleServicesProvider` | **业务开发者** | 按模块分组提供服务列表 |
| `OhServiceFactory` | **业务开发者** | 复杂服务的实例化逻辑 |

---

## 2. 四类协议的实现者

### 2.1 OhService — 业务开发者实现

所有业务模块都实现 `OhService` 协议：

```swift
public protocol OhService: AnyObject, Sendable {
    static var id: String { get }           // 默认：类名字符串
    static var priority: OhPriority { get } // 默认：.medium
    static var retention: OhRetentionPolicy { get } // 默认：.destroy
    static var isLazy: Bool { get }        // 默认：true
    init()                                  // 必须无参
    static func register(in registry: OhRegistry<Self>)
    func serviceDidResolve()                // 实例创建完成回调（主线程）
}
```

### 2.2 OhServiceLoader — 框架内置，业务开发者可选自定义

框架内置了 **4 种** `OhServiceLoader` 实现：

| 实现类 | 职责 | 使用方式 |
|--------|------|----------|
| `OhManifestLoader` | 扫描 OhServices.plist | 方案三 |
| `OhModuleLoader` | 扫描 OhModules.plist | 方案二 |
| `OhSwiftSectionLoader` | 扫描 Mach-O __coo_sw_svc 段 | 方案一 |
| `OhObjcSectionLoader` | 扫描 Mach-O __coo_svc 段 | 配合 OC 宏 |

### 2.3 OhModuleServicesProvider — 业务开发者实现

用于 **按模块分组** 注册服务，实现 `OhServiceLoader` 协议：

```swift
public protocol OhServiceLoader: AnyObject, Sendable {
    init()                              // 必须无参
    func load() -> [OhServiceDefinition]
}
```

### 2.4 OhServiceFactory — 业务开发者实现

用于 **复杂初始化**，当普通 `init()` 无法满足需求时：

```swift
public protocol OhServiceFactory: AnyObject, Sendable {
    init()                                                      // 必须无参
    func make(context: OhContext, args: [String: any Sendable]) -> any OhService
}
```

---

## 3. 三种配置文件详解

### 3.1 OhModules.plist

**用途：** 声明有哪些模块入口类参与服务加载

**配置方式：** 主工程或任意 Bundle 的根目录放置 `OhModules.plist`

**需要实现的协议：** `OhServiceLoader`

**字段说明：**

| 字段 | 类型 | 含义 |
|------|------|------|
| 数组元素 | String | 模块入口类的全名（含模块名） |

**示例：**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <string>MyApp.NetworkModule</string>
    <string>MyApp.AnalyticsModule</string>
</array>
</plist>
```

**框架行为：**
1. `OhModuleLoader` 读取 OhModules.plist
2. 对每个类名调用 `NSClassFromString()` 获取类
3. 检查该类是否实现 `OhServiceLoader` 协议
4. 如果是，实例化并调用 `load()` 获取服务描述符列表

**模块入口类示例：**

```swift
// 实现 OhServiceLoader 协议
final class NetworkModule: OhServiceLoader {
    required init() {}

    func load() -> [OhServiceDefinition] {
        return [
            .service(HttpClient.self, priority: .high, retention: .hold),
            .service(WebSocketService.self, priority: .medium),
            .service(RetryPolicy.self, priority: .low)
        ]
    }
}
```

---

### 3.2 OhServices.plist

**用途：** 声明式注册服务，支持通过 plist 配置参数

**配置方式：** 可以放在以下位置：
- **方式 A：** 模块的 `Info.plist` 中添加 `OhServices` 键
- **方式 B：** 独立文件 `OhServices.plist`，放入 Bundle 资源

**需要实现的协议：** 无（只需实现 `OhService`）

**字段说明：**

| 字段 | 类型 | 必需 | 含义 |
|------|------|------|------|
| `class` | String | **是** | 服务类的全名（含模块名） |
| `priority` | Integer | 否 | 优先级数值（覆盖服务默认值） |
| `retention` | String | 否 | 驻留策略：`hold` 或 `destroy`（覆盖默认值） |
| `args` | Dict | 否 | 静态参数，在 `context.args` 中获取 |
| `factory` | String | 否 | 工厂类全名（用于复杂初始化） |

**示例（方式 A - Info.plist）：**

```xml
<key>OhServices</key>
<array>
    <dict>
        <key>class</key>
        <string>MyApp.ConfigService</string>
        <key>priority</key>
        <integer>750</integer>
        <key>retention</key>
        <string>hold</string>
        <key>args</key>
        <dict>
            <key>apiKey</key>
            <string>abc123</string>
            <key>debugMode</key>
            <true/>
        </dict>
    </dict>
</array>
```

**示例（方式 B - 独立文件）：**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>class</key>
        <string>MyModule.MyService</string>
        <key>priority</key>
        <integer>500</integer>
    </dict>
</array>
</plist>
```

**文件放置位置：**

```
# 动态库（直接在 framework 根目录）
MyModule.framework/
├── MyModule
└── OhServices.plist        ← 直接放在根目录

# 静态库（打包为 .bundle）
MyModule.framework/
├── MyModule
└── MyModule.bundle/
    └── OhServices.plist    ← 放在 bundle 中
```

**框架行为：**
1. `OhManifestLoader` 扫描主 Bundle 和所有 Embedded Frameworks
2. 读取每个 Bundle 的 `Info.plist` 中的 `OhServices` 键
3. 或读取每个 Bundle 中的 `OhServices.plist` 文件
4. 解析数组中的每个 dict，构建 `OhServiceDefinition`

---

### 3.3 Info.plist（内置 OhServices）

**用途：** 与 OhServices.plist 相同，只是配置位置在 `Info.plist` 中

**配置方式：** 在模块的 `Info.plist` 中添加 `OhServices` 键

**需要实现的协议：** 无

**字段说明：** 与 OhServices.plist 完全相同

| 字段 | 类型 | 必需 | 含义 |
|------|------|------|------|
| `class` | String | **是** | 服务类的全名（含模块名） |
| `priority` | Integer | 否 | 优先级数值 |
| `retention` | String | 否 | `hold` 或 `destroy` |
| `args` | Dict | 否 | 静态参数 |
| `factory` | String | 否 | 工厂类全名 |

**示例：**

```xml
<key>OhServices</key>
<array>
    <dict>
        <key>class</key>
        <string>MyModule.MyService</string>
        <key>factory</key>
        <string>MyModule.MyServiceFactory</string>
        <key>args</key>
        <dict>
            <key>baseURL</key>
            <string>https://api.example.com</string>
        </dict>
    </dict>
</array>
```

---

## 4. 三种配置文件的对比

| 特性 | OhModules.plist | OhServices.plist | Info.plist |
|------|-----------------|-----------------|------------|
| **使用场景** | 模块化、多个服务打包 | 单个服务、需传参 | 与 Info.plist 一起 |
| **需要实现的协议** | `OhServiceLoader` | 无 | 无 |
| **支持 args 参数** | 代码中硬编码 | ✅ plist 配置 | ✅ plist 配置 |
| **支持 factory** | 代码中硬编码 | ✅ plist 配置 | ✅ plist 配置 |
| **支持 priority 覆盖** | 代码中硬编码 | ✅ plist 配置 | ✅ plist 配置 |
| **支持 retention 覆盖** | 代码中硬编码 | ✅ plist 配置 | ✅ plist 配置 |
| **适用库类型** | 动态库、静态库 | 动态库、静态库 | 动态库 |

---

## 5. 四种服务注册方案

### 方案一：@OrchService 宏（推荐）

**核心原理：**
- 宏在编译时生成 Mach-O Section 数据
- `OhSwiftSectionLoader` 在运行时扫描 Section 获取类名
- 框架自动创建服务描述符

**谁来实现：**
- 业务开发者实现 `OhService`
- 框架自动处理服务发现

**使用方式：**

```swift
@OrchService()
final class MyService: OhService {
    required init() {}

    static func register(in registry: OhRegistry<MyService>) {
        registry.add(.didFinishLaunching) { service, context in
            print("Service created!")
            return .continue()
        }
    }
}
```

**指定模块名（跨模块时必需）：**

```swift
// 在 MyModule 模块中
@OrchService("MyModule")
final class MyService: OhService {
    // ...
}
```

**AppDelegate 配置：**

```swift
class AppDelegate: OhAppDelegate {
    override var serviceLoaders: [OhServiceLoader] {
        [OhSwiftSectionLoader()]  // 启用 Swift 宏扫描
    }
}
```

---

### 方案二：OhModules.plist + OhServiceLoader

**核心原理：**
- 在 plist 中列出模块入口类名
- `OhModuleLoader` 读取 plist，实例化入口类
- 入口类返回该模块的所有服务描述符

**谁来实现：**
- 业务开发者实现 `OhService`（多个）
- 业务开发者实现 `OhServiceLoader` 协议（模块入口类）

**配置文件：** OhModules.plist

| 字段 | 类型 | 说明 |
|------|------|------|
| 数组元素 | String | 模块入口类全名 |

**使用方式：**

**Step 1：实现模块入口类**

```swift
import CooOrchestrator

/// 网络模块的服务入口（实现 OhServiceLoader）
final class NetworkModule: OhServiceLoader {
    required init() {}

    func load() -> [OhServiceDefinition] {
        return [
            .service(HttpClient.self, priority: .high, retention: .hold),
            .service(WebSocketService.self, priority: .medium),
            .service(RetryPolicy.self, priority: .low)
        ]
    }
}
```

**Step 2：创建 OhModules.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <string>MyApp.NetworkModule</string>
    <string>MyApp.AnalyticsModule</string>
</array>
</plist>
```

**Step 3：AppDelegate 配置**

```swift
class AppDelegate: OhAppDelegate {
    override var serviceLoaders: [OhServiceLoader] {
        [OhModuleLoader()]  // 启用模块加载
    }
}
```

**优点：**
- 服务按模块组织，清晰
- 一个模块可以包含多个服务
- 优先级、参数等在代码中硬编码，易于维护

---

### 方案三：OhServices.plist（声明式）

**核心原理：**
- 在 Info.plist 或独立 plist 文件中声明服务
- `OhManifestLoader` 扫描所有 Bundle 的 plist
- 自动创建服务描述符

**谁来实现：**
- 业务开发者实现 `OhService`
- 无需实现额外协议，只需编写 plist

**配置文件：** OhServices.plist 或 Info.plist

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `class` | String | **是** | 服务类的全名（含模块名） |
| `priority` | Integer | 否 | 优先级数值（覆盖默认值） |
| `retention` | String | 否 | `hold` 或 `destroy` |
| `args` | Dict | 否 | 静态参数，通过 `context.args` 获取 |
| `factory` | String | 否 | 工厂类全名（用于复杂初始化） |

**使用方式：**

**方式 A：在 Info.plist 中添加**

```xml
<key>OhServices</key>
<array>
    <dict>
        <key>class</key>
        <string>MyModule.MyService</string>
        <key>priority</key>
        <integer>750</integer>
        <key>retention</key>
        <string>hold</string>
        <key>args</key>
        <dict>
            <key>apiKey</key>
            <string>abc123</string>
        </dict>
    </dict>
</array>
```

**方式 B：独立 OhServices.plist 文件**

对于静态库（打包为 .bundle）或动态库：

```
MyModule.framework/
├── MyModule
└── MyModule.bundle/
    └── OhServices.plist
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>class</key>
        <string>MyModule.MyService</string>
        <key>priority</key>
        <integer>500</integer>
    </dict>
</array>
</plist>
```

**AppDelegate 配置：**

```swift
class AppDelegate: OhAppDelegate {
    override var serviceLoaders: [OhServiceLoader] {
        [OhManifestLoader()]  // 启用 plist 扫描
    }
}
```

**优点：**
- 声明式配置，无需编写代码
- 支持通过 `args` 传递静态参数
- 支持通过 `factory` 使用工厂模式
- 支持覆盖 `priority` 和 `retention`

---

### 方案四：OhServiceFactory（复杂初始化）

**核心原理：**
- 当服务的初始化需要外部依赖或复杂逻辑时，用工厂代替直接 `init()`
- 在 plist 中指定 `factory` 字段
- 框架实例化工厂类，调用 `make(context:args:)` 创建服务

**谁来实现：**
- 业务开发者实现 `OhService`
- 业务开发者实现 `OhServiceFactory`
- 在 plist 中指定 `factory` 字段

**配置文件：** OhServices.plist 或 Info.plist

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `class` | String | **是** | 服务类的全名 |
| `factory` | String | **是** | 工厂类全名 |
| `args` | Dict | 否 | 传递给工厂的参数 |

**使用方式：**

**Step 1：实现服务**

```swift
/// 网络服务（需要配置参数）
final class NetworkService: OhService {
    private let baseURL: String
    private let timeout: TimeInterval

    init(baseURL: String, timeout: TimeInterval) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    required init() {
        fatalError("NetworkService must be created via factory")
    }

    static func register(in registry: OhRegistry<NetworkService>) {
        registry.add(.didFinishLaunching) { service, context in
            service.connect()
            return .continue()
        }
    }

    func connect() {
        print("Connecting to \(baseURL) with timeout \(timeout)")
    }
}
```

**Step 2：实现工厂（实现 OhServiceFactory）**

```swift
/// 网络服务工厂（实现 OhServiceFactory 协议）
final class NetworkServiceFactory: OhServiceFactory {
    required init() {}

    func make(context: OhContext, args: [String: any Sendable]) -> any OhService {
        let baseURL = args["baseURL"] as? String ?? "https://api.example.com"
        let timeout = args["timeout"] as? TimeInterval ?? 30
        return NetworkService(baseURL: baseURL, timeout: timeout)
    }
}
```

**Step 3：在 plist 中指定工厂**

```xml
<dict>
    <key>class</key>
    <string>MyApp.NetworkService</string>
    <key>factory</key>
    <string>MyApp.NetworkServiceFactory</string>
    <key>retention</key>
    <string>hold</string>
    <key>args</key>
    <dict>
        <key>baseURL</key>
        <string>https://api.example.com</string>
        <key>timeout</key>
        <integer>30</integer>
    </dict>
</dict>
```

**何时需要工厂？**

| 场景 | 普通 init() | 需要工厂 |
|------|-------------|----------|
| 简单服务 | ✅ | ❌ |
| 需要配置文件 | ✅ (通过 args) | ✅ (更灵活) |
| 需要注入依赖 | ❌ | ✅ |
| 复杂构造逻辑 | ❌ | ✅ |
| 条件创建不同实现 | ❌ | ✅ |

---

## 6. 事件系统

### 6.1 预置事件常量

**应用生命周期：**

```swift
OhEvent.didFinishLaunching       // App 启动完成
OhEvent.didBecomeActive         // App 进入活动
OhEvent.willResignActive        // App 将要取消活动
OhEvent.didEnterBackground       // App 进入后台
OhEvent.willEnterForeground     // App 将要进入前台
OhEvent.willTerminate           // App 将要终止
OhEvent.didReceiveMemoryWarning  // 内存警告
```

**Scene 生命周期：**

```swift
OhEvent.sceneWillConnect        // Scene 连接
OhEvent.sceneDidDisconnect      // Scene 断开
OhEvent.sceneDidBecomeActive    // Scene 激活
OhEvent.sceneWillResignActive   // Scene 取消激活
OhEvent.sceneWillEnterForeground // Scene 进入前台
OhEvent.sceneDidEnterBackground  // Scene 进入后台
```

**自定义阶段：**

```swift
OhEvent.appStart   // Scene 启动开始
OhEvent.appReady   // Scene 启动就绪
```

### 6.2 参数键名

```swift
OhParameterKey.application
OhParameterKey.launchOptions
OhParameterKey.scene
OhParameterKey.session
OhParameterKey.userActivity
OhParameterKey.url
```

### 6.3 注册事件

```swift
static func register(in registry: OhRegistry<MyService>) {
    // 基本用法
    registry.add(.didFinishLaunching) { service, context in
        return .continue()
    }

    // 无返回值（默认继续）
    registry.add(.appReady) { service, context in
        // 处理逻辑
    }

    // 获取参数
    registry.add(.didFinishLaunching) { service, context in
        if let app = context.parameters[.application] as? UIApplication {
            print("App: \(app)")
        }
        return .continue()
    }

    // 中断传播
    registry.add(.didFinishLaunching) { service, context in
        return .stop(result: .bool(true))
    }
}
```

---

## 7. 优先级与驻留策略

### 7.1 优先级

```swift
OhPriority.boot      // Int.max  - 最高（日志、Crash监控）
OhPriority.critical  // 1000     - 关键业务
OhPriority.high      // 750      - 高优先级
OhPriority.medium    // 500      - 默认
OhPriority.low       // 250      - 低优先级
```

### 7.2 驻留策略

```swift
OhRetentionPolicy.destroy  // 执行后立即释放（默认）
OhRetentionPolicy.hold     // 保留实例，可通过 Orchestrator.service(of:) 获取
```

**获取常驻服务：**

```swift
if let service = Orchestrator.service(of: MyService.self) {
    service.doSomething()
}
```

---

## 8. 预置观察者协议

### 8.1 OhApplicationObserver

处理 AppDelegate 事件：

```swift
@OrchService()
final class MyService: OhService, OhApplicationObserver {
    static func register(in registry: OhRegistry<MyService>) {
        addApplication(.didFinishLaunching, in: registry)
        addApplication(.didRegisterForRemoteNotifications, in: registry)
    }

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> OhResult {
        print("Launched!")
        return .continue()
    }

    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) -> OhResult {
        print("Token: \(deviceToken)")
        return .continue()
    }
}
```

### 8.2 OhSceneObserver

处理 SceneDelegate 事件：

```swift
@OrchService()
final class MyService: OhService, OhSceneObserver {
    static func register(in registry: OhRegistry<MyService>) {
        addScene(.sceneWillConnect, in: registry)
    }

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions,
               context: OhContext) -> OhResult {
        guard let windowScene = scene as? UIWindowScene else {
            return .continue()
        }
        let window = UIWindow(windowScene: windowScene)
        context.source(as: OhSceneDelegate.self)?.window = window
        window.rootViewController = ViewController()
        window.makeKeyAndVisible()
        return .stop()
    }
}
```

---

## 9. UIKit 集成

### 9.1 AppDelegate

```swift
@main
class AppDelegate: OhAppDelegate {
    // 可选：自定义服务加载器组合
    override var serviceLoaders: [OhServiceLoader] {
        [
            OhManifestLoader(),      // plist 扫描
            OhModuleLoader(),         // 模块加载
            OhSwiftSectionLoader(),  // Swift 宏
            OhObjcSectionLoader()    // OC 宏
        ]
    }
}
```

### 9.2 SceneDelegate

```swift
class SceneDelegate: OhSceneDelegate {
    override func scene(_ scene: UIScene,
                        didConnectingTo session: UISceneSession,
                        options connectionOptions: UIScene.ConnectionOptions) {
        // 可覆盖此方法自定义 Scene 连接逻辑
    }
}
```

### 9.3 服务加载流程

```
App 启动
    │
    ▼
application(_:didFinishLaunchingWithOptions:)
    │
    ├── Orchestrator.resolve(loaders: [...])
    │       │
    │       ├── OhManifestLoader      → 扫描 OhServices.plist / Info.plist
    │       ├── OhModuleLoader        → 扫描 OhModules.plist
    │       ├── OhSwiftSectionLoader → 扫描 Mach-O __coo_sw_svc
    │       └── OhObjcSectionLoader  → 扫描 Mach-O __coo_svc
    │
    └── Orchestrator.fire(.didFinishLaunching, ...)
            │
            └── 按优先级顺序分发事件
```

---

## 10. 完整使用示例

### 示例 1：基础服务（方案一 @OrchService 宏）

```swift
@OrchService()
final class AnalyticsService: OhService {
    static var priority: OhPriority = .high

    required init() {}

    static func register(in registry: OhRegistry<AnalyticsService>) {
        registry.add(.appReady) { service, context in
            service.trackAppReady()
            return .continue()
        }
    }

    func trackAppReady() {
        print("App ready")
    }
}
```

### 示例 2：通过 plist 传参（方案三）

**服务代码：**

```swift
final class ConfigService: OhService {
    static var retention: OhRetentionPolicy = .hold

    required init() {}

    static func register(in registry: OhRegistry<ConfigService>) {
        registry.add(.didFinishLaunching) { service, context in
            let apiKey = context.args["apiKey"] as? String ?? ""
            let debugMode = context.args["debugMode"] as? Bool ?? false
            service.configure(apiKey: apiKey, debugMode: debugMode)
            return .continue()
        }
    }

    func configure(apiKey: String, debugMode: Bool) {
        print("Config: apiKey=\(apiKey), debugMode=\(debugMode)")
    }
}
```

**plist 配置（OhServices.plist）：**

```xml
<array>
    <dict>
        <key>class</key>
        <string>MyApp.ConfigService</string>
        <key>retention</key>
        <string>hold</string>
        <key>args</key>
        <dict>
            <key>apiKey</key>
            <string>abc123</string>
            <key>debugMode</key>
            <true/>
        </dict>
    </dict>
</array>
```

### 示例 3：工厂模式（方案四）

**服务代码（禁止直接 init）：**

```swift
final class NetworkService: OhService {
    private let baseURL: String

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    required init() {
        fatalError("Use NetworkServiceFactory")
    }

    static func register(in registry: OhRegistry<NetworkService>) {
        registry.add(.didFinishLaunching) { service, context in
            service.connect()
            return .continue()
        }
    }

    func connect() {
        print("Connecting to \(baseURL)")
    }
}
```

**工厂代码（实现 OhServiceFactory）：**

```swift
final class NetworkServiceFactory: OhServiceFactory {
    required init() {}

    func make(context: OhContext, args: [String: any Sendable]) -> any OhService {
        let baseURL = args["baseURL"] as? String ?? "https://default.com"
        return NetworkService(baseURL: baseURL)
    }
}
```

**plist 配置（实现 OhServiceFactory）：**

```xml
<dict>
    <key>class</key>
    <string>MyApp.NetworkService</string>
    <key>factory</key>
    <string>MyApp.NetworkServiceFactory</string>
    <key>retention</key>
    <string>hold</string>
    <key>args</key>
    <dict>
        <key>baseURL</key>
        <string>https://api.example.com</string>
    </dict>
</dict>
```

### 示例 4：模块化加载（方案二）

**模块入口类（实现 OhServiceLoader）：**

```swift
final class AnalyticsModule: OhServiceLoader {
    required init() {}

    func load() -> [OhServiceDefinition] {
        return [
            .service(AnalyticsService.self, priority: .high),
            .service(TrackingService.self, priority: .medium),
            .service(ReportService.self, priority: .low)
        ]
    }
}
```

**OhModules.plist：**

```xml
<array>
    <string>MyApp.AnalyticsModule</string>
    <string>MyApp.NetworkModule</string>
</array>
```

### 示例 5：UserInfo 跨服务共享

```swift
// AuthService 设置 token
@OrchService()
final class AuthService: OhService {
    required init() {}

    static func register(in registry: OhRegistry<AuthService>) {
        registry.add(.didFinishLaunching) { service, context in
            context.userInfo[.userToken] = "token_123"
            return .continue()
        }
    }
}

extension OhContextKey {
    static let userToken = OhContextKey("userToken")
}

// UserService 读取 token
@OrchService()
final class UserService: OhService {
    required init() {}

    static func register(in registry: OhRegistry<UserService>) {
        registry.add(.appReady) { service, context in
            if let token = context.userInfo.getString(.userToken) {
                print("Got token: \(token)")
            }
            return .continue()
        }
    }
}
```

---

## 附录：协议与配置文件速查

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CooOrchestrator                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  OhModules.plist                                               │   │
│  │  ─────────────────────────────────────────────────────────── │   │
│  │  字段：数组（元素为 String）                                    │   │
│  │  含义：列出模块入口类名                                        │   │
│  │  需实现协议：OhServiceLoader                                   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  OhServices.plist / Info.plist (OhServices 键)                │   │
│  │  ─────────────────────────────────────────────────────────── │   │
│  │  字段：class, priority, retention, args, factory             │   │
│  │  含义：声明式注册服务及其配置                                  │   │
│  │  需实现协议：无                                               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  @OrchService 宏                                               │   │
│  │  ─────────────────────────────────────────────────────────── │   │
│  │  原理：在 Mach-O Section 中注册服务名                          │   │
│  │  需实现协议：OhService                                         │   │
│  │  配合使用：OhSwiftSectionLoader                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```
