//
//  StreamingTests.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-27.
//
import Testing
@testable import PythonTools

extension Tag {
    @Tag static var outputStreaming: Tag
    @Tag static var errorHandling: Tag
}

@Suite(.tags(.outputStreaming))
struct OutputStreamingTests {
    let outputStream = MockOutputStream()
    
    init() {
        Interpreter.output(to: outputStream)
    }
    
    @Test("Print a simple message")
    func simplePrint() async throws {
        try await Interpreter.run("print('message')")
        
        #expect(outputStream.output == "message\n")
        #expect(outputStream.finalizeCallCount == 1)
    }

    @Test("Check evaluation result")
    func testEvaluation() async throws {
        try await Interpreter.run("2 + 2")
        
        #expect(outputStream.lastEvaluationResult == "4")
    }
    
    @Test("Compilation error", .tags(.errorHandling), arguments: [
        "2+",
        "print(",
        "if True",
    ])
    func testErrorMessage_compilationError(code: String) async throws {
        await #expect {
            try await Interpreter.run(code)
        } throws: { error in
            guard let error = error as? InterpreterError,
                  case let .compilationFailure(message) = error else {
                return false
            }

            return message == outputStream.errorMessage
        }

        #expect(!outputStream.errorMessage.isEmpty)
    }
    
    @Test("Execution error", .tags(.errorHandling), arguments: [
        "1 / 0",
        "'hello' + 10",
        "my_list = [1, 2, 3]; my_list[10]",
    ])
    func testErrorMessage_executionError(code: String) async throws {
        await #expect {
            try await Interpreter.run(code)
        } throws: { error in
            guard let error = error as? InterpreterError,
                  case let .executionFailure(message) = error else {
                return false
            }

            return message == outputStream.errorMessage
        }

        #expect(!outputStream.errorMessage.isEmpty)
    }
}
