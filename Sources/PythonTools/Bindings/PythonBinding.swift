//
//  PythonBinding.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-07-30.
//

import PythonKit
import Foundation
import Python

public struct PythonBinding {
    let className: String
    weak var object: AnyObject?

    public init<Object: AnyObject>(_ object: Object) {
        self.object = object
        className = PythonBinding.className(object.self)
    }
    
    public func createPythonObject() async throws -> PythonObject {
        let address = await address
        
        var result: PythonObject!
        
        try await Interpreter.perform {
            let main = Python.import("__main__")
            result = main[dynamicMember: className](address)
        }
        
        return result
    }
    
    // MARK: Memory address.
    
    @MainActor
    public var address: Int {
        guard let object else { return 0 }
        let reference = Unmanaged.passUnretained(object).toOpaque()
        let address = Int(bitPattern: reference)
        PythonBinding.registry[address] = self
        return address
    }
    
    @MainActor
    public static func from<Object: AnyObject>(address: Int) throws -> Object {
        guard let object = registry[address]?.object else {
            registry[address] = nil
            throw PythonBindingError.instanceDeallocated
        }
        
        guard let result = object as? Object else {
            throw PythonBindingError.instanceDeallocated
        }
        return result
    }
}

// MARK: Register class.

extension PythonBinding {
    @MainActor
    static var registry = [Int : PythonBinding]()

    @MainActor
    static var registeredClasses = Set<String>()
    
    public static func className<Object>(_ object: Object) -> String {
        let type = (object as? Any.Type) ?? type(of: object)
        return String(reflecting: type)
            .replacingOccurrences(of: ".", with: "_")
    }
    
    public static func register<Object>(
        _ object: Object.Type,
        name: String? = nil, in moduleName: String? = nil,
        members: [PropertyRegistration<Object>]
    ) async throws {
        let objectName = className(object)
        
        // Register the Python class.
        try await Interpreter.run(
            """
            class \(objectName):
                def __init__(self, address: int):
                    self._address = address
            """
        )
        
        // Set members.
        try await Interpreter.perform {
            let main = Python.import("__main__")

            let classDef = main[dynamicMember: objectName]

            let property = Python.import("builtins").property

            for member in members {
                classDef[dynamicMember: member.name] = property(
                    member.getterFunction,
                    member.setterFunction,
                    Python.None,
                    Python.None
                )
            }

            // Move to module.
            if let moduleName {
                let module = Python.import(moduleName)
                module[dynamicMember: name ?? objectName] = classDef
                main[dynamicMember: objectName] = Python.None
            }
        }

        Interpreter.log.info("Registered binding: \(objectName)")
    }
}

public struct PropertyRegistration<Root: AnyObject> {
    public typealias Registerable = (PythonConvertible & ConvertibleFromPython)
    
    let name: String
    let getter: (Root) -> PythonConvertible
    let setter: ((inout Root, PythonObject) -> Void)?

    var getterFunction: PythonObject {
        PythonFunction { pythonObject in
            let addressObj = pythonObject._address
            
            let obj: Root? = DispatchQueue.main.sync {
                guard let address = Int(addressObj) else {
                    return nil
                }
                return try? PythonBinding.from(address: address)
            }
            
            guard let obj else { return Python.None }

            return getter(obj)
        }
        .pythonObject
    }

    var setterFunction: PythonObject {
        guard let setter else { return Python.None }
        
        return PythonFunction { pythonObjects in
            let addressObj = pythonObjects[0]._address
            let pythonValue = pythonObjects[1]
            guard let address = Int(addressObj) else {
                return Python.None
            }

            DispatchQueue.main.sync {
                if var obj: Root? = try? PythonBinding.from(address: address) {
                    setter(&obj!, pythonValue)
                }
            }

            return Python.None
        }.pythonObject
    }

    public static func bind<Value>(
        name: String,
        get getter: @escaping (Root) -> Value,
        set setter: ((inout Root, Value) -> Void)? = nil
    ) -> PropertyRegistration where Value: Registerable {
        let anySetter: ((inout Root, PythonObject) -> Void)? = if let setter {
            { root, pythonValue in
                if let value = Value(pythonValue) {
                    setter(&root, value)
                }
            }
        } else { nil }

        return PropertyRegistration<Root>(
            name: name,
            getter: getter,
            setter: anySetter
        )
    }
}

public extension PropertyRegistration {
    static func setterFromKeyPath<Value>(_ path: KeyPath<Root, Value>) -> ((inout Root, Value) -> Void)? {
        if let writablePath = path as? WritableKeyPath<Root, Value> {
            return { root, value in
                root[keyPath: writablePath] = value
            }
        }
        return nil
    }
    
    static func set<Value>(_ name: String, _ path: KeyPath<Root, Value>) -> PropertyRegistration where Value: Registerable {
        .bind(name: name,
              get: { $0[keyPath: path] },
              set: setterFromKeyPath(path))
    }
}

public enum PythonBindingError: Error {
    case instanceDeallocated
}
