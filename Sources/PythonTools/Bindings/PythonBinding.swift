//
//  PythonBinding.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-07-30.
//

import PythonKit
import Foundation
import Python

public protocol PythonBindable: AnyObject, PythonConvertible {
    static func register() async throws
}

public extension PythonBindable {
    var pythonObject: PythonObject {
        PythonBinding(self).pythonObject
    }
}

private extension PythonBindable {
    @MainActor
    static func from(_ pythonObject: PythonObject) -> Self? {
        guard let address = Int(pythonObject._address) else {
            return nil
        }
        
        return try? PythonBinding.from(address: address)
    }
}

public struct PythonBinding {
    let className: String
    weak var object: AnyObject?

    public init<Object: AnyObject>(_ object: Object) {
        self.object = object
        className = PythonBinding.className(object.self)
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

extension PythonBinding: PythonConvertible, ConvertibleFromPython {
    public init?(_ object: PythonObject) {
        return nil
    }
    
    public var pythonObject: PythonObject {
        let (classInfo, address) = DispatchQueue.main.sync {
            let classInfo = Self.registeredClasses[className]
            return (classInfo, self.address)
        }
        
        guard let classInfo else {
            Interpreter.log.fault("Tried to access unregistered class: \(className)")
            return Python.None
        }
        
        let module = Python.import(classInfo.module)
        return module[dynamicMember: classInfo.name](address)
    }
}

// MARK: Register class.

struct PythonClassInfo {
    let name: String
    let module: String
}

extension PythonBinding {
    @MainActor
    static var registry = [Int : PythonBinding]()

    @MainActor
    static var registeredClasses = [String : PythonClassInfo]()
    
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
        
        await MainActor.run {
            registeredClasses[objectName] = PythonClassInfo(
                name: name ?? objectName,
                module: moduleName ?? "__main__"
            )
        }

        Interpreter.log.info("Registered binding: \(objectName)")
    }
}

// MARK: - PropertyRegistration

public struct PropertyRegistration<Root: AnyObject> {
    public typealias Registerable = (PythonConvertible & ConvertibleFromPython)

    let name: String
    let getter: (Root) -> PythonConvertible
    let setter: (@MainActor (inout Root, PythonObject) -> Void)?

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
}

extension PropertyRegistration {
    // MARK: - Value type binders
    
    /// Value type binder.
    /// - Parameters:
    ///   - name: Name of the property in Python.
    ///   - getter: Getter binding.
    ///   - setter: Setter binding.
    /// - Returns: `PropertyRegistration`
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
    
    /// Value type property binder.
    /// - Parameters:
    ///   - name: Name of the property in Python
    ///   - path: Path to the value
    /// - Returns: `PropertyRegistration`
    public static func set<Value>(_ name: String, _ path: KeyPath<Root, Value>) -> PropertyRegistration where Value: Registerable {
        .bind(name: name,
              get: { $0[keyPath: path] },
              set: setterFromKeyPath(path))
    }
    
    /// Value type property binder.
    /// - Parameters:
    ///   - path: Path to the value
    /// - Returns: `PropertyRegistration`
    public static func set<Value>(_ path: KeyPath<Root, Value>) -> PropertyRegistration where Value: Registerable {
        .bind(name: nameFromKeyPath(path),
              get: { $0[keyPath: path] },
              set: setterFromKeyPath(path))
    }
    
    // MARK: - Reference type binders

    /// Reference type binder.
    /// - Parameters:
    ///   - name: Name of the property in Python.
    ///   - getter: Getter binding.
    ///   - setter: Setter binding.
    /// - Returns: `PropertyRegistration`
    public static func bind<Object>(
        name: String,
        get getter: @escaping (Root) -> Object,
        set setter: ((inout Root, Object) -> Void)? = nil
    ) -> PropertyRegistration where Object: PythonBindable {
        let anySetter: (@MainActor (inout Root, PythonObject) -> Void)? = if let setter {
            { root, pythonValue in
                if let value = Object.from(pythonValue) {
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
    
    /// Reference type property binder.
    /// - Parameters:
    ///   - name: Name of the property in Python
    ///   - path: Path to the object
    /// - Returns: `PropertyRegistration`
    public static func set<Object>(_ name: String, _ path: KeyPath<Root, Object>) -> PropertyRegistration where Object: PythonBindable {
        return .bind(name: name,
                     get: { $0[keyPath: path] },
                     set: setterFromKeyPath(path))
    }
    
    /// Reference type property binder.
    /// - Parameters:
    ///   - path: Path to the object
    /// - Returns: `PropertyRegistration`
    public static func set<Object>(_ path: KeyPath<Root, Object>) -> PropertyRegistration where Object: PythonBindable {
        return .bind(name: nameFromKeyPath(path),
                     get: { $0[keyPath: path] },
                     set: setterFromKeyPath(path))
    }

    /// Optional reference type binder.
    /// - Parameters:
    ///   - name: Name of the property in Python.
    ///   - getter: Getter binding.
    ///   - setter: Setter binding.
    /// - Returns: `PropertyRegistration`
    public static func bind<Value>(
        name: String,
        get getter: @escaping (Root) -> Value?,
        set setter: ((inout Root, Value?) -> Void)? = nil
    ) -> PropertyRegistration where Value: PythonBindable {
        let anySetter: (@MainActor (inout Root, PythonObject) -> Void)? = if let setter {
            { root, pythonValue in
                let value = Value.from(pythonValue)
                setter(&root, value)
            }
        } else { nil }

        return PropertyRegistration<Root>(
            name: name,
            getter: getter,
            setter: anySetter
        )
    }
    
    /// Optional reference type property binder.
    /// - Parameters:
    ///   - name: Name of the property in Python
    ///   - path: Path to the object
    /// - Returns: `PropertyRegistration`
    public static func set<Object>(_ name: String, _ path: KeyPath<Root, Object?>) -> PropertyRegistration where Object: PythonBindable {
        .bind(name: name,
              get: { $0[keyPath: path] },
              set: setterFromKeyPath(path))
    }
    
    /// Optional reference type property binder.
    /// - Parameters:
    ///   - path: Path to the object
    /// - Returns: `PropertyRegistration`
    public static func set<Object>(_ path: KeyPath<Root, Object?>) -> PropertyRegistration where Object: PythonBindable {
        .bind(name: nameFromKeyPath(path),
              get: { $0[keyPath: path] },
              set: setterFromKeyPath(path))
    }

    static func nameFromKeyPath<Value>(_ path: KeyPath<Root, Value>) -> String {
        let pathString = String(describing: path)
        let lastElement = pathString.components(separatedBy: ".").last!
        
        // Convert to snake case.
        return lastElement
            .map { char in
                if char.isUppercase { "_" + char.lowercased() }
                else { "\(char)" }
            }
            .joined()
    }
    
    static func setterFromKeyPath<Value>(_ path: KeyPath<Root, Value>) -> ((inout Root, Value) -> Void)? {
        if let writablePath = path as? WritableKeyPath<Root, Value> {
            return { root, value in
                root[keyPath: writablePath] = value
            }
        }
        return nil
    }
}

// MARK: - Errors

public enum PythonBindingError: Error {
    case unregisteredType
    case instanceDeallocated
}
