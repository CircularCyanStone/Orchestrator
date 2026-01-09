//
//  OhAppDelegate.swift
//  CooOrchestrator
//
//  Created by 李奇奇 on 2025/12/29.
//

import UIKit

/// 默认的 AppDelegate 实现，提供标准生命周期事件的转发。
/// - 开发者可以继承此类，并根据需要重写相关方法。
/// - 注意：此类仅转发 `OhAppDelegateEvents` 中定义的标准系统事件。
/// - Important: 子类重写方法时，**必须调用 super** 以确保生命周期事件正确分发。
@main
open class OhAppDelegate: UIResponder, UIApplicationDelegate {
        
    
    /// 定义服务加载器
    /// - Description:
    ///   子类可以通过重写此属性来自定义服务加载策略，而无需重写 application(_:didFinishLaunchingWithOptions:)。
    ///   默认包含 OhModuleLoader (模块加载) 和 OhObjcSectionLoader (OC段加载)。
    open var serviceLoaders: [OhServiceLoader] {
        return [OhModuleLoader(), OhObjcSectionLoader()]
    }

    /// 程序生命周期入口
    /// - Description:
    ///   标准启动入口，负责初始化编排器并分发 .didFinishLaunching 事件。
    ///   如果需要自定义服务源，请重写 `serviceLoaders` 属性。
    open func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 1. 使用配置的源进行服务解析
        Orchestrator.resolve(loaders: self.serviceLoaders)
        
        // 2. 准备参数并分发事件
        let params: [OhParameterKey: Any] = [
            .application: application,
            .launchOptions: launchOptions ?? [:]
        ]
        return Orchestrator.fire(.didFinishLaunching, source: self, parameters: params) ?? true
    }
    
    
    open func applicationDidBecomeActive(_ application: UIApplication) {
        Orchestrator.fire(.didBecomeActive, parameters: [.application: application])
    }
    
    open func applicationWillResignActive(_ application: UIApplication) {
        Orchestrator.fire(.willResignActive, parameters: [.application: application])
    }
    
    open func applicationDidEnterBackground(_ application: UIApplication) {
        Orchestrator.fire(.didEnterBackground, parameters: [.application: application])
    }
    
    open func applicationWillEnterForeground(_ application: UIApplication) {
        Orchestrator.fire(.willEnterForeground, parameters: [.application: application])
    }
    
    open func applicationWillTerminate(_ application: UIApplication) {
        Orchestrator.fire(.willTerminate, parameters: [.application: application])
    }
    
    // MARK: - System Events
    
    open func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        Orchestrator.fire(.didReceiveMemoryWarning, parameters: [.application: application])
    }
    
    open func applicationSignificantTimeChange(_ application: UIApplication) {
        Orchestrator.fire(.significantTimeChange, parameters: [.application: application])
    }
    
    // MARK: - Open URL & User Activity
    
    open func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        let params: [OhParameterKey: Any] = [
            .application: app,
            .url: url,
            .options: options
        ]
        return Orchestrator.fire(.openURL, parameters: params) ?? false
    }
    
    open func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        let params: [OhParameterKey: Any] = [
            .application: application,
            .userActivity: userActivity,
            .restorationHandler: restorationHandler
        ]
        return Orchestrator.fire(.continueUserActivity, parameters: params) ?? false
    }
    
    open func application(_ application: UIApplication, didUpdate userActivity: NSUserActivity) {
        let params: [OhParameterKey: Any] = [
            .application: application,
            .userActivity: userActivity
        ]
        Orchestrator.fire(.didUpdateUserActivity, parameters: params)
    }
    
    open func application(_ application: UIApplication, didFailToContinueUserActivityWithType userActivityType: String, error: Error) {
        let params: [OhParameterKey: Any] = [
            .application: application,
            .activityType: userActivityType,
            .error: error
        ]
        Orchestrator.fire(.didFailToContinueUserActivity, parameters: params)
    }
    
    // MARK: - Background Tasks & Fetch
    
    open func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let params: [OhParameterKey: Any] = [
            .application: application,
            .completionHandler: completionHandler
        ]
        Orchestrator.fire(.performFetch, parameters: params)
    }
    
    open func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        let params: [OhParameterKey: Any] = [
            .application: application,
            .identifier: identifier,
            .completionHandler: completionHandler
        ]
        Orchestrator.fire(.handleEventsForBackgroundURLSession, parameters: params)
    }
    
    // MARK: - Notifications
    
    open func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let params: [OhParameterKey: Any] = [
            .application: application,
            .deviceToken: deviceToken
        ]
        Orchestrator.fire(.didRegisterForRemoteNotifications, parameters: params)
    }
    
    open func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let params: [OhParameterKey: Any] = [
            .application: application,
            .error: error
        ]
        Orchestrator.fire(.didFailToRegisterForRemoteNotifications, parameters: params)
    }
    
    open func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let params: [OhParameterKey: Any] = [
            .application: application,
            .userInfo: userInfo,
            .completionHandler: completionHandler
        ]
        Orchestrator.fire(.didReceiveRemoteNotification, parameters: params)
    }
    
    // MARK: - Scene Session
    
    open func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let params: [OhParameterKey: Any] = [
            .application: application,
            .connectingSceneSession: connectingSceneSession,
            .sceneConnectionOptions: options
        ]
        
        if let config: UISceneConfiguration = Orchestrator.fire(.configurationForConnecting, parameters: params) {
            return config
        }
        
        // 默认使用OhSceneDelegate进行场景代理。
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = OhSceneDelegate.self
        return config
    }
    
    open func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        let params: [OhParameterKey: Any] = [
            .application: application,
            .sceneSessions: sceneSessions
        ]
        Orchestrator.fire(.didDiscardSceneSessions, parameters: params)
    }
}
