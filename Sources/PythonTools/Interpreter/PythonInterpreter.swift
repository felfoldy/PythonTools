//
//  PythonInterpreter.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-25.
//

import Python
import PythonKit
import Foundation

public protocol PythonInterpreter {
    var outputStream: OutputStream { get }
    func execute(block: @escaping () throws -> Void) async throws
}

// MARK: Compilation + execution

extension PythonInterpreter {
    func execute(compiledCode: UnsafeMutablePointer<PyObject>) throws {
        let startTime = DispatchTime.now()
        
        let mainModule = PyImport_AddModule("__main__")
        let globals = PyModule_GetDict(mainModule)
        let result = PyEval_EvalCode(compiledCode, globals, globals)
        
        let endTime = DispatchTime.now()
        
        let executionTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        
        DispatchQueue.main.sync {
            outputStream.execution(time: executionTime)
        }
        
        // Log result.
        guard let result else {
            PyErr_Print()
            
            try DispatchQueue.main.sync {
                throw InterpreterError
                    .executionFailure(outputStream.errorMessage)
            }
            
            return
        }

        defer { Py_DecRef(result) }

        guard Py_IsNone(result) == 0 else { return }

        guard let resultStr = PyObject_Str(result) else {
            return
        }

        if let resultCStr = PyUnicode_AsUTF8(resultStr) {
            DispatchQueue.main.sync {
                outputStream.evaluation(result: String(cString: resultCStr))
            }
        }
        
        Py_DecRef(resultStr)
    }

    public func run(_ code: String) async throws {
        let compilableCode = CompilableCode(source: code)

        let compiledCode = try await Interpreter.compile(code: compilableCode)

        try await execute {
            try execute(compiledCode: compiledCode.byteCode)
        }
    }
}

public enum InterpreterError: LocalizedError, Equatable {
    case failedToLoadBundle
    
    case unexpected(Error)
    case compilationFailure(String)
    case executionFailure(String)

    public var errorDescription: String? {
        switch self {
        case .failedToLoadBundle:
            "Couldn't load bundle"
            
        case let .compilationFailure(message):
            "Failed to compile:\n\(message)"
            
        case let .executionFailure(message):
            message

        case let .unexpected(error):
            "Unexpected error: \(error.localizedDescription)"
        }
    }

    public static func == (lhs: InterpreterError, rhs: InterpreterError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
