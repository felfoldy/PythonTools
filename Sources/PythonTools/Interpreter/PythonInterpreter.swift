//
//  PythonInterpreter.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-25.
//

import Python
import PythonKit
import Foundation

let globals = PyDict_New()
let locals = PyDict_New()

public protocol PythonInterpreter {
    var outputStream: OutputStream { get }
    func execute(block: @escaping () throws -> Void) async throws
}

// MARK: Compilation + execution

extension PythonInterpreter {
    public func compile(code: String) throws -> UnsafeMutablePointer<PyObject> {
        var compiledCode = Py_CompileString(code, "<string>", Py_eval_input)
        
        // If failed to compile as evaluation compile as file input.
        if compiledCode == nil {
            PyErr_Clear()
            compiledCode = Py_CompileString(code, "<string>", Py_file_input)
        }
        
        if let compiledCode {
            return compiledCode
        }
        
        PyErr_Print()

        throw InterpreterError.compilationFailure(outputStream.errorMessage)
    }
    
    func execute(compiledCode: UnsafeMutablePointer<PyObject>) throws {
        let mainModule = PyImport_AddModule("__main__")
        let globals = PyModule_GetDict(mainModule)
        let result = PyEval_EvalCode(compiledCode, globals, globals)
        
        // Log result.
        guard let result else {
            PyErr_Print()

            throw InterpreterError
                .executionFailure(outputStream.errorMessage)
        }

        defer { Py_DecRef(result) }

        guard Py_IsNone(result) == 0 else { return }

        guard let resultStr = PyObject_Str(result) else {
            return
        }

        if let resultCStr = PyUnicode_AsUTF8(resultStr) {
            // TODO: Log result.
            print("Result: " + String(cString: resultCStr))
        }
        
        Py_DecRef(resultStr)
    }

    public func run(_ code: String) async throws {
        try await execute {
            PyErr_Clear()

            let compiledCode = try compile(code: code)
            
            try execute(compiledCode: compiledCode)
            
            Py_DecRef(compiledCode)
        }
    }
}

public enum InterpreterError: LocalizedError {
    case unknown
    case nonZero(Int32)
    case compilationFailure(String)
    case executionFailure(String)

    public var errorDescription: String? {
        switch self {
        case let .nonZero(code):
            "Python script terminated with non-zero exit code: \(code)"
        case let .compilationFailure(message):
            "Failed to compile:\n\(message)"
            
        case let .executionFailure(message):
            "Execution failure:\n\(message)"

        case .unknown:
            ""
        }
    }
}
