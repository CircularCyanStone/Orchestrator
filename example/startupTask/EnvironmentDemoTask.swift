import Foundation
import CooOrchestrator

public final class EnvironmentDemoTask: NSObject, OhService {
    public static let id: String = "env.demo"
    public static let priority: OhPriority = .init(rawValue: 50)
    public static let retention: OhRetentionPolicy = .destroy
    
    // 协议变更：init 必须无参
    public required override init() {
        super.init()
    }

    // 协议变更：注册事件处理
    public static func register(in registry: OhRegistry<EnvironmentDemoTask>) {
        registry.add(.didFinishLaunching) { service, context in
            // 直接使用 Bundle.main，或根据需要使用其他 Bundle
            let bundle = Bundle.main
            let identifier = bundle.bundleIdentifier ?? "unknown.bundle"
            let version = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0"
            let build = (bundle.infoDictionary?["CFBundleVersion"] as? String) ?? "0"

            let msg: String
            if let url = bundle.url(forResource: "EnvDemo", withExtension: "plist", subdirectory: "startupTask"),
               let data = try? Data(contentsOf: url),
               let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let dict = obj as? [String: Any],
               let welcome = dict["WelcomeMessage"] as? String {
                msg = welcome
            } else if let path = bundle.paths(forResourcesOfType: "plist", inDirectory: nil).first(where: { $0.hasSuffix("/startupTask/EnvDemo.plist") }),
                      let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                      let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                      let dict = obj as? [String: Any],
                      let welcome = dict["WelcomeMessage"] as? String {
                msg = welcome
            } else {
                msg = "EnvDemo.plist not found"
            }

            // 依然可以调用 Logging，但实际上 Manager 也会记录一次
            print("EnvironmentDemoTask: bundle=\(identifier) v\(version)(\(build)) msg=\(msg)")
            return .continue()
        }
    }
}
