//
//  ByteCodeExecuter.swift
//  
//
//  Created by Tibor Felföldy on 2024-07-06.
//

import Foundation
import Python

struct ByteCodeExecuter {
    func execute(code: CompiledByteCode) async throws {
        var executionTime: UInt64!
        var result: UnsafeMutablePointer<PyObject>?
        
        try await Interpreter.perform {
            let startTime = DispatchTime.now()
            
            let mainModule = PyImport_AddModule("__main__")
            let globals = PyModule_GetDict(mainModule)
            
            result = PyEval_EvalCode(code.byteCode, globals, globals)
            
            let endTime = DispatchTime.now()
            
            executionTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
            
            if result == nil {
                PyErr_Print()
            }
        }
        
        await Interpreter.shared.outputStream.finalize(
            codeId: code.id,
            executionTime: executionTime
        )
        
        guard let result else {
            let error = await Interpreter.shared.outputStream.errorMessage
            
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
            await Interpreter.shared.outputStream
                .evaluation(result: resultString)
        }
        
        Py_DecRef(resultStr)
    }
}

public extension Interpreter {
    static func execute(compiledCode: CompiledByteCode) async throws {
        let executer = ByteCodeExecuter()
        try await executer.execute(code: compiledCode)
    }
}
