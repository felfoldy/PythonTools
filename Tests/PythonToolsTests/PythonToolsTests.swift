import Testing
import Foundation
@testable import PythonTools

@Test func bundleLoad() async throws {
    let output = MockOutputStream()
    await Interpreter.output(to: output)
    
    try await Interpreter.load(bundle: Bundle.module)
    
    try await Interpreter.run("import libtest")
    try await Interpreter.run("libtest.test_obj.value")
    
    #expect(output.lastEvaluationResult == "10")
}

@Test func codeCompletion() async throws {
    let results = try await Interpreter.completions(code: "pri")
    
    #expect(results == ["print("])
}
