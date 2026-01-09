//
//  AppDelegate.swift
//  example
//
//  Created by 李奇奇 on 2025/12/19.
//

import CooOrchestrator
import DynamicModule2
import UIKit
import exampleModule1

@main
class AppDelegate: OhAppDelegate {
    
    override var serviceLoaders: [any OhServiceLoader] {
        [
            OhManifestLoader()
        ]
    }

    
}
