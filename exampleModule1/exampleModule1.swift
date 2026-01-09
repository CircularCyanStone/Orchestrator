//
//  exampleModule1.swift
//  exampleModule1
//
//  Created by 李奇奇 on 2025/12/23.
//  静态库测试案例

import Foundation
import CooOrchestrator
import UIKit

public final class ExampleModule1: NSObject, OhService, OhApplicationObserver, OhSceneObserver {

    public static func register(in registry: CooOrchestrator.OhRegistry<ExampleModule1>) {
        print("ExampleModule1正在加载")
        addScene(.sceneWillConnect, in: registry)
        addApplication(.didFinishLaunching, in: registry)
    }

    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> OhResult {
        print("ExampleModule1 didFinishLaunchingWithOptions")
        return .continue()
    }
    
    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) -> OhResult {
        print("ExampleModule1 willConnectTo")
        return .continue()
    }
    
}

