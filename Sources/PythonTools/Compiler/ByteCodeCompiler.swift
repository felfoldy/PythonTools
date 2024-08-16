//
//  ByteCodeCompiler.swift
//  
//
//  Created by Tibor Felföldy on 2024-07-05.
//

import Python
import Foundation

public struct ByteCodeCompiler: Compiler {
    enum Error: LocalizedError {
        case multilineSource
        case failed(String)
        
        var errorDescription: String? {
            switch self {
            case let .failed(code):
                "Failed to compile: \(code)"
            case .multilineSource:
                "Multiline source can only be compiled as file type"
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
        
        var name: String {
            switch self {
            case .evaluation: "evaluation"
            case .single: "single"
            case .file: "file"
            }
        }
    }
    
    let type: CompilerType
    
    public func compile(code: CompilableCode) async throws -> CompiledByteCode {
        if type != .file && code.source.contains(where: \.isNewline) {
            throw Error.multilineSource
        }
        
        var byteCode: UnsafeMutablePointer<PyObject>?

        try await Interpreter.perform {
            PyErr_Clear()
            
            byteCode = Py_CompileString(code.source,
                                        code.filename,
                                        type.rawValue)
            
            if byteCode != nil {
                Py_IncRef(byteCode)
            } else {
                if PyErr_Occurred() != nil {
                    PyErr_Clear()
                }
            }
        }
        
        if let byteCode {
            Interpreter.trace(code.id, "compiled [\(type.name)]")
            return CompiledByteCode(id: code.id, byteCode: byteCode)
        }
        
        throw Error.failed(code.source)
    }
}

public extension Compiler where Self == ByteCodeCompiler {
    static var evaluationCompiler: ByteCodeCompiler {
        ByteCodeCompiler(type: .evaluation)
    }
    
    static var singleCompiler: ByteCodeCompiler {
        ByteCodeCompiler(type: .single)
    }
    
    static var fileCompiler: ByteCodeCompiler {
        ByteCodeCompiler(type: .file)
    }
}
