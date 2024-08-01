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
    
    public func pythonObject() async throws -> PythonObject {
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
    
    public static func register<Object: AnyObject>(
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
                    member.getter,
                    member.setter ?? Python.None,
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
    enum PropertyType {
        case int, uint
        case string, bool
        case float
    }

    let name: String
    let path: PartialKeyPath<Root>
    let type: PropertyType

    var getter: PythonObject {
        PythonFunction { pythonObject in
            let addressObj = pythonObject._address
            
            let obj: Root? = DispatchQueue.main.sync {
                guard let address = Int(addressObj) else {
                    return nil
                }
                return try? PythonBinding.from(address: address)
            }
            
            guard let obj else { return Python.None }

            return (obj[keyPath: path] as? PythonConvertible) ?? Python.None
        }
        .pythonObject
    }
    
    var setter: PythonObject? {
        switch type {
        case .int: makeSetter(Int.self)
        case .uint: makeSetter(UInt.self)
        case .string: makeSetter(String.self)
        case .bool: makeSetter(Bool.self)
        case .float: makeSetter(Double.self)
        }
    }
    
    func makeSetter<Value: ConvertibleFromPython>(_ type: Value.Type) -> PythonObject? {
        guard let writablePath = path as? WritableKeyPath<Root, Value> else {
            return nil
        }
        
        return PythonFunction { pythonObjects in
            let addressObj = pythonObjects[0]._address
            guard let address = Int(addressObj),
                  let value = Value(pythonObjects[1]) else {
                return Python.None
            }

            DispatchQueue.main.sync {
                var obj: Root? = try? PythonBinding.from(address: address)
                obj?[keyPath: writablePath] = value
            }

            return Python.None
        }
        .pythonObject
    }
}

public extension PropertyRegistration {
    static func int(_ name: String, _ path: KeyPath<Root, Int>) -> PropertyRegistration {
        PropertyRegistration(name: name, path: path, type: .int)
    }
    
    static func int(_ name: String, _ path: KeyPath<Root, UInt>) -> PropertyRegistration {
        PropertyRegistration(name: name, path: path, type: .uint)
    }

    static func string(_ name: String, _ path: KeyPath<Root, String>) -> PropertyRegistration {
        PropertyRegistration(name: name, path: path, type: .string)
    }

    static func bool(_ name: String, _ path: KeyPath<Root, Bool>) -> PropertyRegistration {
        PropertyRegistration(name: name, path: path, type: .bool)
    }
    
    // In python float is a double.
    static func float(_ name: String, _ path: KeyPath<Root, Double>) -> PropertyRegistration {
        PropertyRegistration(name: name, path: path, type: .float)
    }
    
    // Float will be casted to Double.
    static func float(_ name: String, _ path: KeyPath<Root, Float>) -> PropertyRegistration {
        PropertyRegistration(name: name, path: path, type: .float)
    }
}

public enum PythonBindingError: Error {
    case instanceDeallocated
}
