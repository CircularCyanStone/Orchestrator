import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
import XCTest

@testable import CooOrchestrator

#if canImport(CooOrchestratorMacros)
    // 引入宏的实现类
    import CooOrchestratorMacros
#endif

final class CooOrchestratorTests: XCTestCase {

    func testExpansionLogic() throws {
        // 这里定义的 testMacros 是关键，它把宏名字映射到你的实现类
        let testMacros: [String: Macro.Type] = [
            "OrchService": OhRegisterServiceMacro.self
        ]
        #if canImport(CooOrchestratorMacros)
            // 调用此函数会触发 CORegisterServiceMacro.expansion
            assertMacroExpansion(
                """
                @OrchService
                final class TestServiceA: COService {
                    static func register(in registry: CooOrchestrator.CORegistry<TestServiceA>) {
                        print("模块执行了\(type(of: self))")
                    }
                }
                """,
                expandedSource:
                    """
                    final class TestServiceA: COService {
                        static func register(in registry: CooOrchestrator.CORegistry<TestServiceA>) {
                            print("模块执行了CooOrchestratorTests")
                        }
                        init() {}

                        @_used
                        @_section("__DATA,__coo_svc")
                        static let _coo_svc_entry: (StaticString) = (
                            "TestModule.TestServiceA"
                        )
                    }
                    """,
                macros: testMacros
            )
        #else
            throw XCTSkip(
                "macros are only supported when running tests for the host platform"
            )
        #endif
    }
    
    func testModule() throws {
        let testMacros: [String: Macro.Type] = [
            "OrchModule": OhRegisterModuleMacro.self
        ]

        assertMacroExpansion(
            """
            @OrchModule
            final class TestModuleA {
                init() {}
            }
            extension TestModuleA: OhServiceLoader {
                func load() -> [COServiceDefinition] {[]}
            }
            """,
            expandedSource:
                """
                final class TestModuleA: COServiceSource {
                    init() {}
                    func load() -> [COServiceDefinition] {[]}

                    @_used
                    @_section("__DATA,__coo_mod")
                    static let _coo_mod_entry: (StaticString) = (
                        "TestModule.TestModuleA"
                    )
                }
                """,
            macros: testMacros
        )
    }
}

@OrchModule()
final class TModule {
    
}
extension TModule: OhServiceLoader {
    func load() -> [CooOrchestrator.OhServiceDefinition] {
        []
    }
}
