import Testing
@testable import PythonTools

@Test func runScript_resultsInSuccess() async throws {
    await #expect(throws: Never.self) {
        try await Interpreter.run("print(2 + 2)")
    }
}

@Test func runScript_nonZeroErrors() async throws {
    await #expect(throws: InterpreterError.self) {
        try await Interpreter.run("2 +")
    }
}
