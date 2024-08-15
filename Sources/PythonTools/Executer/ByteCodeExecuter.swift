//
//  ByteCodeExecuter.swift
//  
//
//  Created by Tibor Felföldy on 2024-07-06.
//

import Foundation
import Python

struct ByteCodeExecuter {
    @MainActor
    func execute(code: CompiledByteCode) async throws {
        try await Interpreter.perform {
            // TODO: Cache local and global dictionaries.
            let mainModule = PyImport_AddModule("__main__")
            let globals = PyModule_GetDict(mainModule)
            
            PythonRuntimeMonitor.start()

            PyErr_Clear()
            
            // Code execution.
            let result = PyEval_EvalCode(code.byteCode, globals, globals)

            PythonRuntimeMonitor.end()
            
            if result == nil, PyErr_Occurred() != nil {
                PyErr_Print()
            }
            
            Interpreter.shared.outputStream.finalize(
                codeId: code.id,
                executionTime: PythonRuntimeMonitor.executionTime
            )
            
            guard let result else {
                let error = Interpreter.shared.outputStream.errorMessage
                Interpreter.log.error("\(code.id) - \(error)")
                throw InterpreterError.executionFailure(error)
            }
            
            defer { Py_DecRef(result) }
            
            // Fetch evaluation result.
            guard Py_IsNone(result) == 0 else { return }

            guard let resultStr = PyObject_Str(result) else {
                return
            }
            
            if let resultCStr = PyUnicode_AsUTF8(resultStr) {
                let resultString = String(cString: resultCStr)
                Interpreter.shared.outputStream
                    .evaluation(result: resultString)
            }
            
            Py_DecRef(resultStr)
        }
    }
}

public extension Interpreter {
    static func execute(compiledCode: CompiledByteCode) async throws {
        let executer = ByteCodeExecuter()
        try await executer.execute(code: compiledCode)
    }
}
