// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：OC 桥接层，将 Orchestrator 的核心 public API 暴露为 @objc 方法，供 OC 代码调用。

import Foundation

/// Orchestrator 的 OC 桥接类
/// - 提供与 `Orchestrator` 对应的 OC 可调用方法
/// - 所有参数使用 OC 兼容类型（String/NSDictionary/Any?），内部转换为 Swift 类型后调用原始 API
@objcMembers
public class OrchestratorBridge: NSObject {

    // MARK: - Fire

    /// 触发指定事件的插件执行
    @discardableResult
    public class func fire(_ event: String, source: Any?, parameters: [AnyHashable: Any]?) -> OhObjcResult {
        let ohEvent = OhEvent(rawValue: event)
        let ohParams = convertParameters(parameters)
        let ret = Orchestrator.fire(ohEvent, source: source, parameters: ohParams)
        return OhObjcResult(ret)
    }

    // MARK: - Resolve

    /// 使用默认 loader 启动引导
    public class func resolve() {
        Orchestrator.resolve()
    }

    /// 使用指定 loader 类名列表启动引导
    /// - Parameter classNames: OhPluginLoader 实现类的完整类名数组
    public class func resolve(withLoaderClassNames classNames: [String]) {
        var loaders: [OhPluginLoader] = []
        for name in classNames {
            guard let cls = NSClassFromString(name) as? OhPluginLoader.Type else {
                OhLogger.log("OrchestratorBridge: Class '\(name)' is not a valid OhPluginLoader", level: .warning)
                continue
            }
            loaders.append(cls.init())
        }
        Orchestrator.resolve(loaders: loaders)
    }

    /// 通过插件 ID 获取常驻插件实例
    /// - Parameter id: 插件 ID（通常为类名）
    /// - Returns: 插件实例，如果不存在或策略非 hold 则返回 nil
    public class func plugin(byId id: String) -> Any? {
        return Orchestrator.plugin(of: id)
    }

    // MARK: - Register

    /// 通过插件类名注册插件
    /// - Parameters:
    ///   - className: 插件类的完整类名（如 "MyApp.MyPlugin"）
    ///   - priority: 优先级数值（可选，nil 使用默认值）
    ///   - retention: 驻留策略字符串（"hold" 或 "destroy"，可选，nil 使用默认值）
    ///   - args: 静态参数（可选）
    public class func registerPlugin(className: String, priority: NSNumber?, retention: String?, args: [String: Any]?) {
        guard let cls = NSClassFromString(className) else {
            OhLogger.log("OrchestratorBridge: Class '\(className)' not found", level: .warning)
            return
        }

        let ohPriority = priority.map { OhPriority(rawValue: $0.intValue) }
        let ohRetention = retention.flatMap { OhRetentionPolicy(rawValue: $0) }
        let sendableArgs: [String: Sendable] = args.flatMap { dict in
            var result: [String: Sendable] = [:]
            for (key, value) in dict {
                switch value {
                case let v as String: result[key] = v
                case let v as Int: result[key] = v
                case let v as Double: result[key] = v
                case let v as Bool: result[key] = v
                default: break
                }
            }
            return result
        } ?? [:]

        let desc = OhPluginDefinition(
            pluginClass: cls,
            priority: ohPriority,
            retentionPolicy: ohRetention,
            args: sendableArgs
        )
        Orchestrator.register([desc])
    }

    // MARK: - Private

    private class func convertParameters(_ dict: [AnyHashable: Any]?) -> [OhParameterKey: Any] {
        guard let dict else { return [:] }
        var result: [OhParameterKey: Any] = [:]
        for (key, value) in dict {
            if let strKey = key as? String {
                result[OhParameterKey(rawValue: strKey)] = value
            }
        }
        return result
    }
}
