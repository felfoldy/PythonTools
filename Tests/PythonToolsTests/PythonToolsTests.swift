import Testing
@testable import PythonTools

@Test func runScript_resultsInSuccess() async throws {
    try await Interpreter.setup()

    await #expect(throws: Never.self) {
        try await Interpreter.run("print(2 + 2)")
    }
}

@Test func runScript_nonZeroErrors() async throws {
    try await Interpreter.setup()

    await #expect(throws: Interpreter.Error.self) {
        try await Interpreter.run("2 +")
    }
}
