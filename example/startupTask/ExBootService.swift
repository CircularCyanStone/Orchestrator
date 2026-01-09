//
//  ExBootService.swift
//  example
//
//  Created by 李奇奇 on 2025/12/30.
//

import UIKit
import CooOrchestrator

final class ExBootService: OhService, OhSceneObserver {
    
    static var priority: OhPriority = .boot
    
    static func register(in registry: CooOrchestrator.OhRegistry<ExBootService>) {
        addScene(.sceneWillConnect, in: registry)
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions, context: OhContext) -> OhResult {
        guard let windowScene = scene as? UIWindowScene else {
            return .stop()
        }
        let sceneDelegate = context.source(as: OhSceneDelegate.self)
        let window = UIWindow(windowScene: windowScene)
        sceneDelegate?.window = window
        window.rootViewController = ViewController()
        window.makeKeyAndVisible()
        print("window ok")
        return .stop()
    }
}
