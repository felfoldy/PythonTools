//
//  OutputErrorCompiler.swift
//  
//
//  Created by Tibor Felföldy on 2024-07-06.
//

import Python

struct OutputErrorCompiler: Compiler {
    let base: Compiler
    
    func compile(code: CompilableCode) async throws -> CompiledByteCode {
        do {
            return try await base.compile(code: code)
        } catch {
            try await Interpreter.perform {
                PyErr_Print()
            }

            let errorMessage = Interpreter.shared.outputStream.errorMessage

            throw InterpreterError.compilationFailure(errorMessage)
        }
    }
}

extension Compiler {
    func outputError() -> Compiler {
        OutputErrorCompiler(base: self)
    }
}
