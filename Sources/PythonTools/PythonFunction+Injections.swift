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
    
    /// `(Object) -> PythonConvertible`
    static func instanceFunction<Object: PythonBindable>(
        _ fn: @escaping (Object) -> PythonConvertible
    ) -> PythonObject {
        PythonInstanceMethod { (objects: [PythonObject]) in
            PythonRuntimeMonitor.event("extract argument 0: self")

            guard let addrObj = objects.first?.checking._address,
                  let address = Int(addrObj),
                  let obj: Object = try? PythonBinding.from(address: address) else {
                return Python.None
            }

            PythonRuntimeMonitor.event("execute function")
            return fn(obj)
        }.pythonObject
    }
    
    /// `(inout Object) -> PythonConvertible`
    static func instanceFunction<Object: PythonBindable>(
        _ fn: @escaping (inout Object) -> PythonConvertible
    ) -> PythonObject {
        PythonInstanceMethod { (objects: [PythonObject]) in
            PythonRuntimeMonitor.event("extract argument 0: self")

            guard let addrObj = objects.first?.checking._address,
                  let address = Int(addrObj),
                  var obj: Object = try? PythonBinding.from(address: address) else {
                return Python.None
            }

            PythonRuntimeMonitor.event("execute function")
            return fn(&obj)
        }.pythonObject
    }
    
    /// `(inout Object, PythonObject) -> PythonConvertible`
    static func instanceFunction<Object: PythonBindable>(
        _ fn: @escaping (inout Object, PythonObject) -> PythonConvertible
    ) -> PythonObject {
        PythonInstanceMethod { (objects: [PythonObject]) in
            PythonRuntimeMonitor.event("extract argument 0: self")

            guard let addrObj = objects[0].checking._address,
                  let address = Int(addrObj),
                  var obj: Object = try? PythonBinding.from(address: address) else {
                return Python.None
            }

            PythonRuntimeMonitor.event("execute function")

            return fn(&obj, objects[1])
        }.pythonObject
    }
    
    // MARK: - Methods
    
    /// `(inout Object, PythonObject) -> Void`
    static func instanceMethod<Object: PythonBindable>(
        _ fn: @escaping (inout Object, PythonObject) -> Void
    ) -> PythonObject {
        .instanceFunction { (obj: inout Object, value: PythonObject) in
            fn(&obj, value)
            return Python.None
        }
    }
}
