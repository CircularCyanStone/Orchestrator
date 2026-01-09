//
//  SceneDelegate.swift
//  example
//
//  Created by 李奇奇 on 2025/12/19.
//

import UIKit
import CooOrchestrator

class SceneDelegate: OhSceneDelegate {

    override func scene(_ scene: UIScene, didConnectingTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
    }

}

