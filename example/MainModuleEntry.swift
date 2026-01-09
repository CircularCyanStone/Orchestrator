import Foundation
import CooOrchestrator

/// 示例：主模块的服务注册入口
/// 遵循 OhServiceLoader 协议，通过纯代码返回服务列表
class MainModuleEntry: OhServiceLoader {
    
    required init() {}
    
    func load() -> [OhServiceDefinition] {
        return [
            // 使用便捷泛型 API 注册服务
            // 演示：注册 EnvironmentDemoTask
            .service(EnvironmentDemoTask.self, priority: .high)
        ]
    }
}
