//
//  CompilerTests.swift
//  
//
//  Created by Tibor Felföldy on 2024-07-05.
//

import Testing
@testable import PythonTools

extension Tag {
    @Tag static var compiler: Tag
}

@Suite(.tags(.compiler))
struct CompilerTests {
    
    @Test func preserveId() async throws {
        let compilableCode = CompilableCode(source: "print('secret')")
        let byteCode = try await ByteCodeCompiler(type: .single)
            .compile(code: compilableCode)
        
        #expect(compilableCode.id == byteCode.id)
    }
    
    @Test func evaluationCompiler() async throws {
        let evalCompiler = ByteCodeCompiler(type: .evaluation)
        
        await #expect(throws: Never.self) {
            try await evalCompiler.compile("12 + 3")
        }
    }
    
    @Test func skipCompile() async throws {
        let compiler = ByteCodeCompiler(type: .evaluation)
        
        await #expect(throws: ByteCodeCompiler.Error.self) {
            try await compiler.compile("""
            print(1)
            print(2)
            """)
        }
    }
}
