//
//  OhSceneDelegate.swift
//  CooOrchestrator
//
//  Created by 李奇奇 on 2025/12/29.
//

import UIKit

/// 默认的 SceneDelegate 实现，提供标准 Scene 生命周期事件的转发。
/// - 开发者可以继承此类，并根据需要重写相关方法。
/// - 注意：此类仅转发 `OhSceneDelegateEvents` 中定义的标准系统事件。
/// - Important: 子类重写方法时，**必须调用 super** 以确保生命周期事件正确分发。
open class OhSceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    open var window: UIWindow?
    
    // MARK: - Scene Life Cycle
    
    /// Scene 连接（核心生命周期）
    /// - Important: 子类重写此方法时，**必须调用 super** 以确保生命周期事件正确分发。
    /// - Note: 此方法内部会自动触发 `.appStart` (如果 window 为 nil) -> `.sceneWillConnect` -> `.appReady` (如果 window 为 nil)。
    // @requires_super // Swift 中没有官方的 requires_super 属性，通常通过文档或 NSRequiresSuper (OC) 约束
    open func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // 判断是否是“主窗口启动”场景
        // 如果 window 还没创建，我们视为一次完整的冷启动或新窗口创建流程，触发 Start/Ready 语义
        // 如果 window 已经存在（Storyboard 自动加载），则这只是系统回调的一个中间态，依然触发事件，但语义上 window 已经 ready 了
        let isColdStart = (window == nil)
        
        let params: [OhParameterKey: Any] = [
            .scene: scene,
            .session: session,
            .connectionOptions: connectionOptions
        ]
        
        // 1. 启动开始（仅在 Window 未创建时触发，作为纯代码启动的最早时机）
        if isColdStart {
            Orchestrator.fire(.appStart, source: self, parameters: params)
        }
        
        // 2. 标准生命周期回调
        self.scene(scene, didConnectingTo: session, options: connectionOptions)
        Orchestrator.fire(.sceneWillConnect, source: self, parameters: params)
        
        // 3. 启动就绪（仅在 Window 未创建时触发，意味着 sceneWillConnect 内部应该已经完成了 Window 创建）
        if isColdStart {
            Orchestrator.fire(.appReady, source: self, parameters: params)
        }
    }
    
    open func scene(_ scene: UIScene, didConnectingTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
    }
    
    open func sceneDidDisconnect(_ scene: UIScene) {
        Orchestrator.fire(.sceneDidDisconnect, parameters: [.scene: scene])
    }
    
    open func sceneDidBecomeActive(_ scene: UIScene) {
        Orchestrator.fire(.sceneDidBecomeActive, parameters: [.scene: scene])
    }
    
    open func sceneWillResignActive(_ scene: UIScene) {
        Orchestrator.fire(.sceneWillResignActive, parameters: [.scene: scene])
    }
    
    open func sceneWillEnterForeground(_ scene: UIScene) {
        Orchestrator.fire(.sceneWillEnterForeground, parameters: [.scene: scene])
    }
    
    open func sceneDidEnterBackground(_ scene: UIScene) {
        Orchestrator.fire(.sceneDidEnterBackground, parameters: [.scene: scene])
    }
    
    // MARK: - Scene Events
    
    open func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        let params: [OhParameterKey: Any] = [
            .scene: scene,
            .urlContexts: URLContexts
        ]
        Orchestrator.fire(.sceneOpenURLContexts, parameters: params)
    }
    
    open func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        let params: [OhParameterKey: Any] = [
            .scene: scene,
            .userActivity: userActivity
        ]
        Orchestrator.fire(.sceneContinueUserActivity, parameters: params)
    }
    
    open func scene(_ scene: UIScene, didUpdate userActivity: NSUserActivity) {
        let params: [OhParameterKey: Any] = [
            .scene: scene,
            .userActivity: userActivity
        ]
        Orchestrator.fire(.sceneDidUpdateUserActivity, parameters: params)
    }
    
    open func scene(_ scene: UIScene, didFailToContinueUserActivityWithType userActivityType: String, error: Error) {
        let params: [OhParameterKey: Any] = [
            .scene: scene,
            .activityType: userActivityType,
            .error: error
        ]
        Orchestrator.fire(.sceneDidFailToContinueUserActivity, parameters: params)
    }
    
    open func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        let params: [OhParameterKey: Any] = [.scene: scene]
        return Orchestrator.fire(.sceneStateRestorationActivity, parameters: params)
    }
}
