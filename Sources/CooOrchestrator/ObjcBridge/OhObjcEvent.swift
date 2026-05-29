// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：OC 桥接层，提供预置事件名字符串常量，方便 OC 代码直接引用。

import Foundation

/// OC 可用的事件名常量
/// - 每个常量对应 `OhEvent` 扩展中的同名静态属性，值为 rawValue 字符串
/// - OC 侧使用：`[OrchestratorBridge fire:OhObjcEvent.didFinishLaunching ...]`
@objcMembers
public class OhObjcEvent: NSObject {

    private override init() {}

    // MARK: - App Launch & Termination

    @objc public static let didFinishLaunching: String = "didFinishLaunching"
    @objc public static let willTerminate: String = "willTerminate"

    // MARK: - App State Transition

    @objc public static let didBecomeActive: String = "didBecomeActive"
    @objc public static let willResignActive: String = "willResignActive"
    @objc public static let didEnterBackground: String = "didEnterBackground"
    @objc public static let willEnterForeground: String = "willEnterForeground"

    // MARK: - System Events

    @objc public static let didReceiveMemoryWarning: String = "didReceiveMemoryWarning"
    @objc public static let significantTimeChange: String = "significantTimeChange"

    // MARK: - Open URL & User Activity

    @objc public static let openURL: String = "openURL"
    @objc public static let continueUserActivity: String = "continueUserActivity"
    @objc public static let didUpdateUserActivity: String = "didUpdateUserActivity"
    @objc public static let didFailToContinueUserActivity: String = "didFailToContinueUserActivity"

    // MARK: - Background Tasks & Fetch

    @objc public static let performFetch: String = "performFetch"
    @objc public static let handleEventsForBackgroundURLSession: String = "handleEventsForBackgroundURLSession"

    // MARK: - Notifications

    @objc public static let didRegisterForRemoteNotifications: String = "didRegisterForRemoteNotifications"
    @objc public static let didFailToRegisterForRemoteNotifications: String = "didFailToRegisterForRemoteNotifications"
    @objc public static let didReceiveRemoteNotification: String = "didReceiveRemoteNotification"

    // MARK: - Scene

    @objc public static let configurationForConnecting: String = "configurationForConnecting"
    @objc public static let didDiscardSceneSessions: String = "didDiscardSceneSessions"

    // MARK: - Scene Lifecycle

    @objc public static let sceneWillConnect: String = "sceneWillConnect"
    @objc public static let sceneDidDisconnect: String = "sceneDidDisconnect"
    @objc public static let sceneDidBecomeActive: String = "sceneDidBecomeActive"
    @objc public static let sceneWillResignActive: String = "sceneWillResignActive"
    @objc public static let sceneWillEnterForeground: String = "sceneWillEnterForeground"
    @objc public static let sceneDidEnterBackground: String = "sceneDidEnterBackground"
    @objc public static let sceneOpenURLContexts: String = "sceneOpenURLContexts"
    @objc public static let sceneContinueUserActivity: String = "sceneContinueUserActivity"
    @objc public static let sceneDidUpdateUserActivity: String = "sceneDidUpdateUserActivity"
    @objc public static let sceneDidFailToContinueUserActivity: String = "sceneDidFailToContinueUserActivity"
    @objc public static let sceneStateRestorationActivity: String = "sceneStateRestorationActivity"
}
