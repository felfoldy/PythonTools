//
//  PythonFunctionObject.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-25.
//

import PythonKit

public extension PythonObject {

    /// `() -> Output`
    static func inject<Output: PythonConvertible>(_ fn: @escaping () -> Output) -> PythonObject {
        PythonFunction { _ in
            fn()
        }
        .pythonObject
    }
    
    /// `() -> Void`
    static func inject(_ fn: @escaping () -> Void) -> PythonObject {
        .inject { // () -> Output as None
            fn()
            return Python.None
        }
    }
    
    /// `(Input) -> Void`
    static func inject<Input: ConvertibleFromPython>(_ fn: @escaping (Input) -> Void) -> PythonObject {
        PythonFunction { (object: PythonObject) in
            let input = Input(object)!
            fn(input)
            return Python.None
        }
        .pythonObject
    }
}
