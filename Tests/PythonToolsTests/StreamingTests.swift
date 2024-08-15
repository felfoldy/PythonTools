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
@MainActor
struct OutputStreamingTests {
    let outputStream = MockOutputStream()
    
    init() {
        Interpreter.output(to: outputStream)
    }
    
    @Test("Print a simple message")
    func simplePrint() async throws {
        try await Interpreter.run("print('message')")
        
        #expect(outputStream.output == "message")
        #expect(outputStream.finalizeCallCount == 1)
    }
    
    @Test("Code ID")
    func finalizedCodeID() async throws {
        let compilableCode = CompilableCode(source: "print('message')")
        let compiledCode = try await Interpreter.compile(code: compilableCode)
        try await Interpreter.execute(compiledCode: compiledCode)
        
        let codeId = try #require(outputStream.lastCodeId)
        
        #expect(codeId == compilableCode.id)
    }
    
    @Test("Check evaluation result")
    func evaluation() async throws {
        try await Interpreter.run("2 + 2")
        
        #expect(outputStream.lastEvaluationResult == "4")
    }
    
    @Test
    func executionTime() async throws {
        try await Interpreter.run("print('something')")
        
        let executionTime = try #require(outputStream.lastExecutionTime)
        #expect(executionTime > 0)
    }
    
    @Test("Compilation error", .tags(.errorHandling), arguments: [
        "2+",
        "print(",
        "if True",
    ])
    func errorMessage_compilationError(code: String) async throws {
        await #expect {
            try await Interpreter.run(code)
        } throws: { @MainActor error in
            guard let error = error as? InterpreterError,
                  case let .compilationFailure(message) = error else {
                return false
            }
            
            return message == outputStream.errorMessage
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        #expect(!outputStream.errorMessage.isEmpty)
    }
    
    @Test("Execution error", .tags(.errorHandling), arguments: [
        "1 / 0",
        "'hello' + 10",
        "my_list = [1, 2, 3]; my_list[10]",
    ])
    func errorMessage_executionError(code: String) async throws {
        await #expect {
            try await Interpreter.run(code)
        } throws: { @MainActor error in
            guard let error = error as? InterpreterError,
                  case let .executionFailure(message) = error else {
                return false
            }
            
            return message.trimmingCharacters(in: .whitespacesAndNewlines) == outputStream.errorMessage
        }

        #expect(!outputStream.errorMessage.isEmpty)
    }
    
    @Test func clear() async throws {
        try await Interpreter.run("clear()")
        
        #expect(outputStream.clearCallCount == 1)
    }
}
