//
//  StreamingTests.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-27.
//
import Testing
@testable import PythonTools
import Foundation

extension Tag {
    @Tag static var outputStreaming: Tag
    @Tag static var errorHandling: Tag
}

@Suite(.tags(.outputStreaming), .serialized)
@MainActor
class OutputStreamingTests {
    let outputStream = MockOutputStream()
    
    init() {
        Interpreter.output(to: outputStream)
    }
    
    @MainActor
    @Test func bundleLoad() async throws {
        try await Interpreter.load(bundle: Bundle.module)
        
        try await Interpreter.run("import libtest")
        try await Interpreter.run("libtest.test_obj.value")
        
        #expect(outputStream.evaluationResults.contains("10"))
    }
    
    @Test("Print a simple message")
    func simplePrint() async throws {
        try await Interpreter.run("print('message')")
        
        #expect(outputStream.outputBuffer.contains("message"))
        #expect(outputStream.finalizeCallCount > 0)
    }
    
    @Test("Code ID")
    func finalizedCodeID() async throws {
        let compilableCode = CompilableCode(source: "print('message')")
        let compiledCode = try await Interpreter.compile(code: compilableCode)
        try await Interpreter.execute(compiledCode: compiledCode)
        
        #expect(outputStream.finalizedCodes.contains(compilableCode.id))
    }
    
    @Test("Check evaluation result")
    func evaluation() async throws {
        try await Interpreter.run("2 + 2")
        
        #expect(outputStream.evaluationResults.contains("4"))
    }
    
    @Test
    func executionTime() async throws {
        try await Interpreter.run("print('something')")
        
        let executionTime = try #require(outputStream.lastExecutionTime)
        #expect(executionTime > 0)
    }
    
    @Test("Compilation error",
          .disabled("Compilation error streaming is not implemented yet."),
          .tags(.errorHandling),
          arguments: ["2+",
                      "print(",
                      "if True"])
    func errorMessage_compilationError(code: String) async throws {
        await #expect {
            try await Interpreter.run(code)
        } throws: { @MainActor error in
            guard let error = error as? InterpreterError,
                  case let .compilationFailure(message) = error else {
                return false
            }
            
            return outputStream.errorMessage.contains(message)
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
            
            return outputStream.errorMessage.contains(message)
        }

        #expect(!outputStream.errorMessage.isEmpty)
    }
    
    @Test func clear() async throws {
        try await Interpreter.run("clear()")
        
        #expect(outputStream.clearCallCount >= 1)
    }
}
