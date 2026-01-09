// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：定义标准执行阶段事件。
// 类型功能描述：这些事件并非系统原生代理回调，而是对关键生命周期或任务流的细粒度拆分与扩展。

import Foundation

public extension OhEvent {
    
    // MARK: - Launch Phases
    
    /// Scene通用启动开始阶段
    /// - 含义：标识 Scene 启动流程的开始点。
    /// - 触发时机：OhSceneDelegate通常在 willConnectTo rootViewController确定之前触发。
    /// - 通常情况appStart仅支持手动构建window和window.rootViewController；
    /// 如果你是用默认的Main.storyboard初始化的说明接受了系统的安排。
    /// OhSceneDelegate不再自动触发该事件，需要开发者根据自己的实际情况进行触发。
    /// - 非OhSceneDelegate如有需要开发者根据实际情况自行分发该事件
    static let appStart = OhEvent(rawValue: "appStart")
    
    /// Scene通用启动就绪阶段
    /// - 含义：标识 Scene 启动流程的结束点（Ready）。
    /// - 触发时机：OhSceneDelegate通常在 willConnectTo 之后触发。理论上需要用户在
    /// willConnectTo中完成widnow和rootViewController的确定
    /// - 通常情况appReady仅支持手动构建window和window.rootViewController；
    /// 如果你是用默认的Main.storyboard初始化的说明接受了系统的安排。
    /// OhSceneDelegate不再自动触发该事件，需要开发者根据自己的实际情况进行触发。
    /// - 非OhSceneDelegate如有需要开发者根据实际情况自行分发该事件
    static let appReady = OhEvent(rawValue: "appReady")
    
}
