import Testing
@testable import PythonTools

@Test func runScript_resultsInSuccess() async throws {
    let interpreter = await Interpreter()

    await #expect(throws: Never.self) {
        try await interpreter.run(script: "2 + 2")
    }
}

@Test func runScript_nonZeroErrors() async throws {
    let interpreter = await Interpreter()

    await #expect(throws: Interpreter.Error.self) {
        try await interpreter.run(script: "2 +")
    }
}
