//
//  TestServices.swift
//  SPMExample
//
//  Created by Coo on 2025/12/26.
//

import Foundation
import CooOrchestrator

// MARK: - 模块内服务 (通过 Module 注册)

// 服务 A
final class TestServiceA: OhPlugin {
    required init() {}
    
    static func register(in registry: OhPluginRegistry<TestServiceA>) {
        // 注册一些事件...
        registry.add(.didFinishLaunching) { s, c in
            print("TestServiceA didFinishLaunching")
        }
        
        registry.add(.appReady) { s, c in
            print("TestServiceA appReady")
        }
        print("TestServiceA registered")
    }
}

// 服务 B
@OrchService()
final class TestServiceB: OhPlugin {
    required init() {}
    
    
    static func register(in registry: OhPluginRegistry<TestServiceB>) {
        registry.add(.didFinishLaunching) { s, c in
            print("TestServiceB didFinishLaunching")
        }
        
        registry.add(.appReady) { s, c in
            print("TestServiceB appReady")
        }
        print("TestServiceB registered")
    }
    
    
}

// MARK: - 独立服务 (使用 @OrchService 直接注册)

// 服务 C
@OrchService()
final class TestServiceC: OhPlugin {
    required init() {}
    
    static func register(in registry: OhPluginRegistry<TestServiceC>) {
        registry.add(.didFinishLaunching) { s, c in
            print("TestServiceC didFinishLaunching")
        }
        
        registry.add(.appReady) { s, c in
            print("TestServiceC appReady")
        }
        print("TestServiceC registered via Macro")
    }
}

// 服务 D
@OrchService("SPMExample")
final class TestServiceD: OhPlugin {
    required init() {}
    
    static func register(in registry: OhPluginRegistry<TestServiceD>) {
        registry.add(.didFinishLaunching) { s, c in
            print("TestServiceD didFinishLaunching")
        }
        
        registry.add(.appReady) { s, c in
            print("TestServiceD appReady")
        }
        print("TestServiceD registered via Macro")
    }
}

