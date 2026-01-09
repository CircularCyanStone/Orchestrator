// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：示例工程中的推送初始化任务，展示在 MainActor 上执行并作为 resident 常驻的任务。
// 类型功能描述：PushNotificationInitTask 实现 StartupTask 协议，早期时机执行，优先级高，执行后被调度器持有。

import Foundation
import CooOrchestrator
import UIKit

public final class PushNotificationInitTask: NSObject, OhService, OhApplicationObserver {
    public static let id: String = "push.init"
    public static let priority: OhPriority = .init(rawValue: 200)
    public static let retention: OhRetentionPolicy = .hold
    
    // 协议变更：init 必须无参
    public required override init() {
        super.init()
    }

    // 协议变更：注册事件处理
    public static func register(in registry: OhRegistry<PushNotificationInitTask>) {
        // 注册启动事件 (委托给 dispatchApplicationEvent)
        addApplication(.didFinishLaunching, in: registry)
        addApplication(.didRegisterForRemoteNotifications, in: registry)
        registry.add(.sceneDidBecomeActive) { s, c in
            //
            print("========")
        }
        registry.add(.sceneWillResignActive) { s, c in
            print("========")
        }
    }
    
    // MARK: - OhApplicationObserver
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> OhResult {
        print("PushNotificationInitTask: Initializing SDK...")
        return .continue()
    }
    
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) -> OhResult {
        print("PushNotificationInitTask: Registered token: \(deviceToken)")
        return .continue()
    }
}
