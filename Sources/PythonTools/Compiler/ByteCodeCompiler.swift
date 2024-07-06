//
//  ByteCodeCompiler.swift
//  
//
//  Created by Tibor Felföldy on 2024-07-05.
//

import Python
import Foundation

public struct BytCodeCompiler: Compiler {
    enum Error: LocalizedError {
        case failed(String)
        
        var errorDescription: String? {
            switch self {
            case let .failed(code):
                "Failed to compile: \(code)"
            }
        }
    }
    
    enum CompilerType: Int32 {
        /// Expression evaluations.
        case evaluation
        
        /// Single statement for the interactive interpreter loop.
        case single
        
        /// For compiling arbitrarily long Python source code.
        case file
        
        var rawValue: Int32 {
            switch self {
            case .evaluation: Py_eval_input
            case .single: Py_single_input
            case .file: Py_file_input
            }
        }
    }
    
    let type: CompilerType
    
    public func compile(code: CompilableCode) async throws -> CompiledByteCode {
        var byteCode: UnsafeMutablePointer<PyObject>?

        try await Interpreter.perform {
            PyErr_Clear()
            
            byteCode = Py_CompileString(code.source,
                                        code.filename,
                                        type.rawValue)
        }
        
        if let byteCode {
            return CompiledByteCode(id: code.id, byteCode: byteCode)
        }
        
        throw Error.failed(code.source)
    }
}

public extension Compiler where Self == BytCodeCompiler {
    static var evaluationCompiler: BytCodeCompiler {
        BytCodeCompiler(type: .evaluation)
    }
    
    static var singleCompiler: BytCodeCompiler {
        BytCodeCompiler(type: .single)
    }
    
    static var fileCompiler: BytCodeCompiler {
        BytCodeCompiler(type: .file)
    }
}
