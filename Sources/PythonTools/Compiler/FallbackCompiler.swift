//
//  FallbackCompiler.swift
//  
//
//  Created by Tibor Felföldy on 2024-07-05.
//

private struct FallbackCompiler: Compiler {
    let base: Compiler
    let other: Compiler
    
    func compile(code: CompilableCode) async throws -> CompiledByteCode {
        if let result = try? await base.compile(code: code) {
            return result
        }
        return try await other.compile(code: code)
    }
}

extension Compiler {
    func fallback(to other: Compiler) -> Compiler {
        FallbackCompiler(base: self, other: other)
    }
}
