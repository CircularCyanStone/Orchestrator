import Foundation
import CooOrchestrator

/// 示例：主模块的服务注册入口
/// 遵循 OhPluginLoader 协议，通过纯代码返回服务列表
class MainModuleEntry: OhPluginLoader {
    
    required init() {}
    
    func load() -> [OhPluginDefinition] {
        return [
            // 使用便捷泛型 API 注册服务
            // 演示：注册 EnvironmentDemoTask
            .plugin(EnvironmentDemoTask.self, priority: .high)
        ]
    }
}
