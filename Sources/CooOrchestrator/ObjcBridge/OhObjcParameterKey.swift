// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：OC 桥接层，提供预置参数 Key 字符串常量，方便 OC 代码直接引用。

import Foundation

/// OC 可用的参数 Key 常量
/// - 每个常量对应 `OhParameterKey` 扩展中的同名静态属性，值为 rawValue 字符串
/// - OC 侧使用：`[OrchestratorBridge fire:OhObjcEvent.didFinishLaunching parameters:@{OhObjcParameterKey.application: app}]`
@objcMembers
public class OhObjcParameterKey: NSObject {

    private override init() {}

    // MARK: - Common

    @objc public static let application: String = "application"
    @objc public static let launchOptions: String = "launchOptions"
    @objc public static let error: String = "error"
    @objc public static let userInfo: String = "userInfo"
    @objc public static let completionHandler: String = "completionHandler"

    // MARK: - URL & Activity

    @objc public static let url: String = "url"
    @objc public static let options: String = "options"
    @objc public static let userActivity: String = "userActivity"
    @objc public static let restorationHandler: String = "restorationHandler"
    @objc public static let activityType: String = "activityType"

    // MARK: - Notifications

    @objc public static let deviceToken: String = "deviceToken"

    // MARK: - Background

    @objc public static let identifier: String = "identifier"

    // MARK: - Scene Session

    @objc public static let connectingSceneSession: String = "connectingSceneSession"
    @objc public static let sceneConnectionOptions: String = "sceneConnectionOptions"
    @objc public static let sceneSessions: String = "sceneSessions"

    // MARK: - Window Scene

    @objc public static let scene: String = "scene"
    @objc public static let session: String = "session"
    @objc public static let connectionOptions: String = "connectionOptions"
    @objc public static let urlContexts: String = "urlContexts"
}
