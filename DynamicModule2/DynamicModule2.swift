//
//  DynamicModule2.swift
//  DynamicModule2
//
//  Created by 李奇奇 on 2025/12/23.
//  动态库测试案例

import Foundation
import CooOrchestrator
import UIKit

public final class DModule2: NSObject, OhService, OhApplicationObserver, OhSceneObserver {

    public static func register(in registry: CooOrchestrator.OhRegistry<DModule2>) {
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

