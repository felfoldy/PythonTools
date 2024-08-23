//
//  PythonBinding.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-07-30.
//

import PythonKit
import Foundation
import Python

public protocol PythonBindable: ObservableDeinitialization, PythonConvertible {
    static var pythonModule: String { get }
    static var pythonClassName: String { get }
    static func register() async throws
}

extension PythonBindable {}

public extension PythonBindable {
    static var pythonModule: String { "__main__" }
    
    var pythonModule: String { Self.pythonModule }
    var pythonClassName: String { Self.pythonClassName }
    
    var address: Int {
        let reference = Unmanaged.passUnretained(self).toOpaque()
        return Int(bitPattern: reference)
    }

    /// Use `withPythonObject` to ensure thread safety.
    var pythonObject: PythonObject {
        let address = address
        // If there is a binding registered return that.
        if let binding = PythonBinding.registry[address]?.pythonObject {
            return binding
        }
        
        // Else create a new binding.
        if let binding = PythonBinding(address: address, self)?.pythonObject {
            return binding
        }
        return Python.None
    }

    @MainActor
    func withPythonObject(_ block: @MainActor (PythonObject) throws -> Void) throws {
        try Interpreter.performOnMain {
            let initObject = pythonObject
            try block(initObject)
        }
    }
    
    func withPythonObject(_ block: @escaping (PythonObject) throws -> Void) async throws {
        try await Interpreter.perform { [weak self] in
            if let pythonObject = self?.pythonObject {
                try block(pythonObject)
            }
        }
    }
    
    static func withPythonClass(_ block: @escaping (PythonObject) -> Void) async throws {
        let module = pythonModule
        let name = pythonClassName
        
        try await Interpreter.perform {
            let object = Python.import(module)[dynamicMember: name]
            block(object)
        }
    }
    
    @discardableResult
    func binding() async throws -> PythonBinding {
        try await Self.register()
        
        let address = address
        
        var binding: PythonBinding?
        try await Interpreter.perform {
            binding = PythonBinding(address: address, self)
        }
        
        guard let binding else {
            // This should never be called
            throw PythonBindingError.unregisteredType
        }
                
        return binding
    }
}

public extension PythonBindable {
    static func from(_ pythonObject: PythonObject) -> Self? {
        guard let _address = pythonObject.checking._address,
              let address = Int(_address) else {
            return nil
        }

        return PythonBinding.registry[address]?.object as? Self
    }
}

public class PythonBinding {
    /// Swift bindable reference.
    weak var object: PythonBindable?
    /// Python reference.
    var pythonObject: PythonObject?

    public var propertyReferences: [String : PythonBindable] = [:]

    init?<Object: PythonBindable>(address: Int, _ object: Object) {
        self.object = object
        
        // Create python object reference.
        guard let module = try? Python.attemptImport(object.pythonModule),
              let pythonClass = module.checking[dynamicMember: object.pythonClassName] else {
            Interpreter.log.fault("Failed to create python object \(object.pythonClassName)")
            return nil
        }
        self.pythonObject = pythonClass(object.address)
        
        PythonBinding.registry[address] = self
        
        Interpreter.log.trace("[\(Object.pythonClassName)] binding created")
        
        object.onDeinit {
            Task {
                try? await Interpreter.perform {
                    PythonBinding.registry[address]?.pythonObject = nil
                    PythonBinding.registry[address] = nil
                    Interpreter.log.trace("[\(Object.pythonClassName)] binding removed")
                }
            }
        }
    }
    
    @available(*, deprecated, renamed: "binding()")
    @discardableResult
    public static func make<Object: PythonBindable>(_ object: Object) async throws -> PythonBinding {
        try await object.binding()
    }
    
    public func withPythonObject(_ block: @escaping (PythonObject) -> Void) async throws {
        try await Interpreter.perform { [weak self] in
            if let pythonObject = self?.pythonObject {
                block(pythonObject)
            }
        }
    }
}

// MARK: Register class.

enum SubReferences {
    typealias PropertyReference = [String : PythonBindable]
    
    static var map: [Int : PropertyReference] = [:]
}

extension PythonBinding {
    static var registry = [Int : PythonBinding]()
    private static var registeredClasses: Set<String> = []
    
    public static func register<Object>(
        _ object: Object.Type,
        subclass: String = "SwiftManagedObject",
        members: [PropertyRegistration<Object>]
    ) async throws {        
        // Register the Python class.
        try await Interpreter.perform {
            // Prevent registering the same class again.
            if PythonBinding.registeredClasses.contains(Object.pythonClassName) {
                return
            }
            
            let swiftManaged = Python.import("swiftbinding")[dynamicMember: subclass]
            
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
            
            Interpreter.log.info("Registered binding: \(object.pythonModule).\(object.pythonClassName)")
            registeredClasses.insert(Object.pythonClassName)
        }
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

    public static func cache<Value>(
        _ name: String,
        make: @escaping (Root) -> Value
    ) -> PropertyRegistration where Value: PythonBindable {
        PropertyRegistration<Root>(
            name: name,
            getter: { root in
                let address = root.address
                
                if let reference = PythonBinding.registry[address]?.propertyReferences[name] {
                    return reference
                }
                
                let newReference = make(root)
                PythonBinding.registry[address]?.propertyReferences[name] = newReference
                return newReference
            },
            setter: nil
        )
    }
    
    public static func collection<Value: Collection>(
        _ name: String,
        _ path: KeyPath<Root, Value>
    ) -> PropertyRegistration where Value.Element: PythonConvertible,
                                    Value.Index: ConvertibleFromPython {
        .cache(name) { root in
            PythonCollection(base: root, path: path)
        }
    }
}

// MARK: - Errors

public enum PythonBindingError: Error {
    case unregisteredType
    case instanceDeallocated
}
