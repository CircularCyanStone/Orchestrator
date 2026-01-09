
#if canImport(UIKit)

// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：提供预置系统事件的便捷协议与扩展，简化常用生命周期方法的接入。

import Foundation
import UIKit

/// 标准 AppDelegate 生命周期观察者协议
/// - 开发者可以选择遵守此协议，直接实现对应的生命周期方法，而无需在 `register` 中手动 switch event。
/// - 所有方法均返回 `OhResult`，支持责任链控制（如阻断后续服务）。
/// - 注意：此协议不继承 `OhService`，需显式遵守 `OhService` 协议并手动注册感兴趣的事件。
public protocol OhApplicationObserver: Sendable {
    // MARK: - App Life Cycle
    
    /// App 启动完成 (didFinishLaunchingWithOptions)
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?, context: OhContext) -> OhResult
    
    /// App 进入活动状态 (didBecomeActive)
    func applicationDidBecomeActive(_ application: UIApplication, context: OhContext) -> OhResult
    
    /// App 将要取消活动状态 (willResignActive)
    func applicationWillResignActive(_ application: UIApplication, context: OhContext) -> OhResult
    
    /// App 进入后台 (didEnterBackground)
    func applicationDidEnterBackground(_ application: UIApplication, context: OhContext) -> OhResult
    
    /// App 将要进入前台 (willEnterForeground)
    func applicationWillEnterForeground(_ application: UIApplication, context: OhContext) -> OhResult
    
    /// App 将要终止 (willTerminate)
    func applicationWillTerminate(_ application: UIApplication, context: OhContext) -> OhResult
    
    // MARK: - System Events (Memory, Time)
    
    /// 收到内存警告 (didReceiveMemoryWarning)
    func applicationDidReceiveMemoryWarning(_ application: UIApplication, context: OhContext) -> OhResult
    
    /// 系统时间发生显著改变 (significantTimeChange)
    func applicationSignificantTimeChange(_ application: UIApplication, context: OhContext) -> OhResult
    
    // MARK: - Open URL & User Activity
    
    /// 打开 URL (open url)
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any], context: OhContext) -> OhResult
    
    /// 继续用户活动 (continue userActivity)
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void, context: OhContext) -> OhResult
    
    /// 用户活动更新 (didUpdate userActivity)
    func application(_ application: UIApplication, didUpdate userActivity: NSUserActivity, context: OhContext) -> OhResult
    
    /// 用户活动获取失败 (didFailToContinueUserActivity)
    func application(_ application: UIApplication, didFailToContinueUserActivityWithType userActivityType: String, error: Error, context: OhContext) -> OhResult
    
    // MARK: - Background Tasks & Fetch
    
    /// 后台应用刷新 (performFetchWithCompletionHandler)
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void, context: OhContext) -> OhResult
    
    /// 后台 URL Session 事件 (handleEventsForBackgroundURLSession)
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void, context: OhContext) -> OhResult
    
    // MARK: - Notifications
    
    /// 注册远程推送成功 (didRegisterForRemoteNotificationsWithDeviceToken)
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data, context: OhContext) -> OhResult
    
    /// 注册远程推送失败 (didFailToRegisterForRemoteNotificationsWithError)
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error, context: OhContext) -> OhResult
    
    /// 收到远程推送 (didReceiveRemoteNotification)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void, context: OhContext) -> OhResult
    
    // MARK: - Scene
    
    /// 配置新场景 (configurationForConnecting)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions, context: OhContext) -> OhResult
    
    /// 丢弃场景 (didDiscardSceneSessions)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>, context: OhContext) -> OhResult
}

// MARK: - Default Implementation & Routing

public extension OhApplicationObserver {
    
    // MARK: Default Implementations (Return .continue())
    static func addApplication<Service: OhService & OhApplicationObserver>(_ event: OhEvent, in registry: OhRegistry<Service>) {
        registry.add(event) { s, c in
            try s.dispatchApplicationEvent(c)
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?, context: OhContext) -> OhResult { .continue() }
    func applicationDidBecomeActive(_ application: UIApplication, context: OhContext) -> OhResult { .continue() }
    func applicationWillResignActive(_ application: UIApplication, context: OhContext) -> OhResult { .continue() }
    func applicationDidEnterBackground(_ application: UIApplication, context: OhContext) -> OhResult { .continue() }
    func applicationWillEnterForeground(_ application: UIApplication, context: OhContext) -> OhResult { .continue() }
    func applicationWillTerminate(_ application: UIApplication, context: OhContext) -> OhResult { .continue() }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication, context: OhContext) -> OhResult { .continue() }
    func applicationSignificantTimeChange(_ application: UIApplication, context: OhContext) -> OhResult { .continue() }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any], context: OhContext) -> OhResult { .continue() }
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void, context: OhContext) -> OhResult { .continue() }
    func application(_ application: UIApplication, didUpdate userActivity: NSUserActivity, context: OhContext) -> OhResult { .continue() }
    func application(_ application: UIApplication, didFailToContinueUserActivityWithType userActivityType: String, error: Error, context: OhContext) -> OhResult { .continue() }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void, context: OhContext) -> OhResult { .continue() }
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void, context: OhContext) -> OhResult { .continue() }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data, context: OhContext) -> OhResult { .continue() }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error, context: OhContext) -> OhResult { .continue() }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void, context: OhContext) -> OhResult { .continue() }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions, context: OhContext) -> OhResult { .continue() }
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>, context: OhContext) -> OhResult { .continue() }
    
    // MARK: - Internal Dispatcher
    
    /// 将通用上下文分发到具体的协议方法
    /// - Parameter context: 服务上下文
    /// - Returns: 执行结果
    @discardableResult
    private func dispatchApplicationEvent(_ context: OhContext) throws -> OhResult {
        // 尝试从参数中获取 UIApplication
        // 注意：由于 serve 方法非隔离，无法直接访问 MainActor 的 UIApplication.shared，必须通过参数传递
        guard let app = context.parameters[.application] as? UIApplication else {
            // 如果缺少 application 参数，无法执行后续逻辑，直接跳过
            return .continue()
        }
        
        switch context.event {
        case .didFinishLaunching:
            let options = context.parameters[.launchOptions] as? [UIApplication.LaunchOptionsKey: Any]
            return application(app, didFinishLaunchingWithOptions: options, context: context)
            
        case .didBecomeActive:
            return applicationDidBecomeActive(app, context: context)
            
        case .willResignActive:
            return applicationWillResignActive(app, context: context)
            
        case .didEnterBackground:
            return applicationDidEnterBackground(app, context: context)
            
        case .willEnterForeground:
            return applicationWillEnterForeground(app, context: context)
            
        case .willTerminate:
            return applicationWillTerminate(app, context: context)
            
        case .didReceiveMemoryWarning:
            return applicationDidReceiveMemoryWarning(app, context: context)
            
        case .significantTimeChange:
            return applicationSignificantTimeChange(app, context: context)
            
        case .openURL:
            guard let url = context.parameters[.url] as? URL,
                  let options = context.parameters[.options] as? [UIApplication.OpenURLOptionsKey : Any] else {
                return .continue()
            }
            return application(app, open: url, options: options, context: context)
            
        case .continueUserActivity:
            guard let activity = context.parameters[.userActivity] as? NSUserActivity,
                  let handler = context.parameters[.restorationHandler] as? ([UIUserActivityRestoring]?) -> Void else {
                return .continue()
            }
            return application(app, continue: activity, restorationHandler: handler, context: context)
            
        case .didUpdateUserActivity:
            guard let activity = context.parameters[.userActivity] as? NSUserActivity else { return .continue() }
            return application(app, didUpdate: activity, context: context)
            
        case .didFailToContinueUserActivity:
            guard let type = context.parameters[.activityType] as? String,
                  let error = context.parameters[.error] as? Error else { return .continue() }
            return application(app, didFailToContinueUserActivityWithType: type, error: error, context: context)
            
        case .performFetch:
            guard let handler = context.parameters[.completionHandler] as? (UIBackgroundFetchResult) -> Void else { return .continue() }
            return application(app, performFetchWithCompletionHandler: handler, context: context)
            
        case .handleEventsForBackgroundURLSession:
            guard let identifier = context.parameters[.identifier] as? String,
                  let handler = context.parameters[.completionHandler] as? () -> Void else { return .continue() }
            return application(app, handleEventsForBackgroundURLSession: identifier, completionHandler: handler, context: context)
            
        case .didRegisterForRemoteNotifications:
            guard let token = context.parameters[.deviceToken] as? Data else { return .continue() }
            return application(app, didRegisterForRemoteNotificationsWithDeviceToken: token, context: context)
            
        case .didFailToRegisterForRemoteNotifications:
            guard let error = context.parameters[.error] as? Error else { return .continue() }
            return application(app, didFailToRegisterForRemoteNotificationsWithError: error, context: context)
            
        case .didReceiveRemoteNotification:
            guard let userInfo = context.parameters[.userInfo] as? [AnyHashable : Any],
                  let handler = context.parameters[.completionHandler] as? (UIBackgroundFetchResult) -> Void else {
                return .continue()
            }
            return application(app, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: handler, context: context)
            
        case .configurationForConnecting:
            guard let session = context.parameters[.connectingSceneSession] as? UISceneSession,
                  let options = context.parameters[.sceneConnectionOptions] as? UIScene.ConnectionOptions else {
                return .continue()
            }
            return application(app, configurationForConnecting: session, options: options, context: context)
            
        case .didDiscardSceneSessions:
            guard let sessions = context.parameters[.sceneSessions] as? Set<UISceneSession> else { return .continue() }
            return application(app, didDiscardSceneSessions: sessions, context: context)
            
        default:
            return .continue()
        }
    }
}
#endif
