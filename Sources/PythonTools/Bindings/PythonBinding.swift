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
    static var pythonModule: String { get }
    static var pythonClassName: String { get }
    static func register() async throws
}

public extension PythonBindable {
    static var pythonModule: String { "__main__" }
    
    var pythonModule: String { Self.pythonModule }
    var pythonClassName: String { Self.pythonClassName }
    
    var pythonObject: PythonObject {
        PythonBinding(self).pythonObject
    }
    
    static func withClassPythonObject(_ block: @escaping (PythonObject) -> Void) async throws {
        let module = pythonModule
        let name = pythonClassName
        
        try await Interpreter.perform {
            let object = Python.import(module)[dynamicMember: name]
            block(object)
        }
    }
}

private extension PythonBindable {
    static func from(_ pythonObject: PythonObject) -> Self? {
        guard let address = Int(pythonObject._address) else {
            return nil
        }
        
        return try? PythonBinding.from(address: address)
    }
}

public struct PythonBinding {
    weak var object: PythonBindable?

    public init<Object: PythonBindable>(_ object: Object) {
        self.object = object
    }
    
    // MARK: Memory address.

    public var address: Int {
        guard let object else { return 0 }
        let reference = Unmanaged.passUnretained(object as AnyObject).toOpaque()
        let address = Int(bitPattern: reference)
        PythonBinding.registry[address] = self
        return address
    }

    public static func from<Object: PythonBindable>(address: Int) throws -> Object {
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

extension PythonBinding: PythonConvertible {
    public var pythonObject: PythonObject {
        guard let object else {
            Interpreter.log.fault("Tried to access deallocated type")
            return Python.None
        }

        do {
            let module = try Python.attemptImport(object.pythonModule)
            return module[dynamicMember: object.pythonClassName](address)
        } catch {
            return Python.None
        }
    }
}

// MARK: Register class.

extension PythonBinding {
    static var registry = [Int : PythonBinding]()
    
    public static func register<Object>(
        _ object: Object.Type,
        members: [PropertyRegistration<Object>]
    ) async throws {
        try await Interpreter.load(bundle: .module)
        
        // Register the Python class.
        try await Interpreter.perform {
            let swiftManaged = Python.import("swiftbinding").SwiftManagedObject
            
            let classDef = PythonClass(
                object.pythonClassName,
                superclasses: [swiftManaged]
            ).pythonObject
            
            let module = try Python.attemptImport(object.pythonModule)
            module[dynamicMember: object.pythonClassName] = classDef
            
            let property = Python.import("builtins").property
            
            for member in members {
                classDef[dynamicMember: member.name] = property(
                    member.getterFunction,
                    member.setterFunction,
                    Python.None,
                    Python.None
                )
            }
        }

        Interpreter.log.info("Registered binding: \(object.pythonModule).\(object.pythonClassName)")
    }
}

// MARK: - PropertyRegistration

public struct PropertyRegistration<Root: PythonBindable> {
    public typealias Registerable = (PythonConvertible & ConvertibleFromPython)

    let name: String
    let getter: (Root) -> PythonConvertible
    let setter: ((inout Root, PythonObject) -> Void)?

    var getterFunction: PythonObject {
        .instanceFunction { (obj: Root) in
            let result = getter(obj)

            PythonRuntimeMonitor.event("getter - end")
            return result
        }
    }

    var setterFunction: PythonObject {
        guard let setter else { return Python.None }
        
        return .instanceMethod { (obj: inout Root, pythonValue) in
            setter(&obj, pythonValue)
            
            PythonRuntimeMonitor.event("setter - end")
        }
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
        let anySetter: ((inout Root, PythonObject) -> Void)? = if let setter {
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
        let anySetter: ((inout Root, PythonObject) -> Void)? = if let setter {
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

public extension PythonBindable {
    
    
    static func method<Input: ConvertibleFromPython>(fn: @escaping (Self, Input) -> Void) -> PythonObject {
        PythonFunction { pythonObjects in
            PythonRuntimeMonitor.event("extract argument 0: self")
            var args = pythonObjects
            
            let addressObj = args.removeFirst()._address
            guard let address = Int(addressObj) else {
                return Python.None
            }
            
            let obj: Self? = try? PythonBinding.from(address: address)

            PythonRuntimeMonitor.event("extract argument 1")
            guard let obj, let argObj = args.first,
                  let arg = Input(argObj) else { return Python.None }
            
            fn(obj, arg)
            
            return Python.None
        }.pythonObject
    }
}
