//
//  DynamicModule2.swift
//  DynamicModule2
//
//  Created by 李奇奇 on 2025/12/23.
//  动态库测试案例

import Foundation
import CooOrchestrator
import UIKit

public final class DModule2: NSObject, OhPlugin, OhApplicationObserver, OhSceneObserver {

    // 协议要求 `@MainActor init()`；显式声明的非隔离 init 满足该要求，
    // 但继承自 NSObject 的 init 不被接受，故此处显式提供。
    public required override init() {
        super.init()
    }

    public static func register(in registry: CooOrchestrator.OhPluginRegistry<DModule2>) {
        print("DynamicModule2正在加载")
        addScene(.sceneWillConnect, in: registry)
        addApplication(.didFinishLaunching, in: registry)
    }

    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> OhResult {
        print("DynamicModule2 didFinishLaunchingWithOptions")
        return .continue()
    }
    
    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) -> OhResult {
        print("DynamicModule2 willConnectTo")
        return .continue()
    }
    
}

