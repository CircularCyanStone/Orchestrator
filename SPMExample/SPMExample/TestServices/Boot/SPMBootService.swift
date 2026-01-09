//
//  SPMBootService.swift
//  SPMExample
//
//  Created by 李奇奇 on 2025/12/31.
//

import UIKit
import CooOrchestrator

@OrchService()
final class SPMBootService: OhService, OhSceneObserver {
    static func register(in registry: CooOrchestrator.OhRegistry<SPMBootService>) {
        addScene(.sceneWillConnect, in: registry)
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions, context: OhContext) -> OhResult {
        guard let windowScene = scene as? UIWindowScene else {
            return .stop(result: .void, success: false, message: "scene as? UIWindowScene失败")
        }
        let sceneDelegate = context.source as? OhSceneDelegate
        sceneDelegate?.window = UIWindow(windowScene: windowScene)
        sceneDelegate?.window?.rootViewController = ViewController()
        sceneDelegate?.window?.makeKeyAndVisible()
        return .stop()
    }

}
