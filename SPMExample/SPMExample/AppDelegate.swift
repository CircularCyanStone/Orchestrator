//
//  AppDelegate.swift
//  SPMExample
//
//  Created by 李奇奇 on 2025/12/27.
//

import UIKit
import CooOrchestrator

@main
class AppDelegate: OhAppDelegate {

    override var serviceLoaders: [OhServiceLoader] {
        [OhSwiftSectionLoader()]
    }
    
}

