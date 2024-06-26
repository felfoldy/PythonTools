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
    func execute(block: @escaping () throws -> Void) async throws
}

extension PythonInterpreter {
    func compile(code: String) -> UnsafeMutablePointer<PyObject>? {
        var compiledCode = Py_CompileString(code, "<string>", Py_eval_input)
        
        // If failed to compile as evaluation compile as file input.
        if compiledCode == nil {
            PyErr_Clear()
            compiledCode = Py_CompileString(code, "<string>", Py_file_input)
        }

        if compiledCode == nil {
            PyErr_Print()
            PyErr_Clear()
        }
        
        return compiledCode
    }
    
    public func eval(_ code: String) async throws {
        try await execute {
            guard let compiledCode = compile(code: code) else {
                return
            }
            
            let mainModule = PyImport_AddModule("__main__")
            let globals = PyModule_GetDict(mainModule)
            let result = PyEval_EvalCode(compiledCode, globals, globals)
            
            // Log result.
            guard let result, Py_IsNone(result) == 0 else {
                PyErr_Print()
                PyErr_Clear()
                return
            }
            
            defer { Py_DecRef(result) }
            
            guard let resultStr = PyObject_Str(result) else {
                return
            }
            
            defer { Py_DecRef(resultStr) }

            if let resultCStr = PyUnicode_AsUTF8(resultStr) {
                print("\(code): \(String(cString: resultCStr))")
            }
        }
    }
}

public enum InterpreterError: LocalizedError {
    case nonZero(Int32)
    
    public var errorDescription: String? {
        switch self {
        case let .nonZero(code):
            "Python script terminated with non-zero exit code: \(code)"
        }
    }
}
