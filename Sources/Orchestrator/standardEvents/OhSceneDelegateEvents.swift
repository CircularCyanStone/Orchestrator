// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：定义标准生命周期事件（AppDelegate & SceneDelegate）的 Event 常量与参数 Key。

import Foundation

// MARK: - App Lifecycle Event Definitions

public extension OhEvent {
    
    // MARK: - Scene Lifecycle (WindowScene)
    
    /// Scene 连接 (scene:willConnectTo:options:)
    static let sceneWillConnect = OhEvent(rawValue: "sceneWillConnect")
    /// Scene 断开 (sceneDidDisconnect)
    static let sceneDidDisconnect = OhEvent(rawValue: "sceneDidDisconnect")
    /// Scene 激活 (sceneDidBecomeActive)
    static let sceneDidBecomeActive = OhEvent(rawValue: "sceneDidBecomeActive")
    /// Scene 取消激活 (sceneWillResignActive)
    static let sceneWillResignActive = OhEvent(rawValue: "sceneWillResignActive")
    /// Scene 进入前台 (sceneWillEnterForeground)
    static let sceneWillEnterForeground = OhEvent(rawValue: "sceneWillEnterForeground")
    /// Scene 进入后台 (sceneDidEnterBackground)
    static let sceneDidEnterBackground = OhEvent(rawValue: "sceneDidEnterBackground")
    
    // MARK: - Scene Events
    
    /// Scene 打开 URL上下文 (scene:openURLContexts:)
    static let sceneOpenURLContexts = OhEvent(rawValue: "sceneOpenURLContexts")
    /// Scene 继续用户活动 (scene:continue:)
    static let sceneContinueUserActivity = OhEvent(rawValue: "sceneContinueUserActivity")
    /// Scene 更新用户活动 (scene:didUpdate:)
    static let sceneDidUpdateUserActivity = OhEvent(rawValue: "sceneDidUpdateUserActivity")
    /// Scene 用户活动失败 (scene:didFailToContinueUserActivity:error:)
    static let sceneDidFailToContinueUserActivity = OhEvent(rawValue: "sceneDidFailToContinueUserActivity")
    /// Scene 恢复状态 (stateRestorationActivity(for:))
    static let sceneStateRestorationActivity = OhEvent(rawValue: "sceneStateRestorationActivity")
}

// MARK: - Lifecycle Parameter Keys

public extension OhParameterKey {
    
    // MARK: - Scene Session
    static let connectingSceneSession = OhParameterKey(rawValue: "connectingSceneSession")
    static let sceneConnectionOptions = OhParameterKey(rawValue: "sceneConnectionOptions")
    static let sceneSessions = OhParameterKey(rawValue: "sceneSessions")
    
    // MARK: - Window Scene
    static let scene = OhParameterKey(rawValue: "scene")
    static let session = OhParameterKey(rawValue: "session")
    static let connectionOptions = OhParameterKey(rawValue: "connectionOptions")
    static let urlContexts = OhParameterKey(rawValue: "urlContexts")
}
