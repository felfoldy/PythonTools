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
    public weak var object: AnyObject?

    public init<Object: AnyObject>(_ object: Object) {
        self.object = object
    }
    
    // MARK: Memory address.
    
    public var address: Int {
        guard let object else { return 0 }
        let reference = Unmanaged.passUnretained(object).toOpaque()
        let address = Int(bitPattern: reference)
        PythonBinding.registry[address] = self
        return address
    }
    
    public static func from<Object: AnyObject>(address: Int) throws -> Object {
        guard let result = registry[address]?.object as? Object else {
            registry[address] = nil
            throw PythonBindingError.instanceDeallocated
        }
        return result
    }
    
    // MARK: Register class.
    
    public static func className<Object>(_ object: Object) -> String {
        let type = (object as? Any.Type) ?? type(of: object)
        return String(reflecting: type)
            .replacingOccurrences(of: ".", with: "_")
    }
    
    public static func register<Object: AnyObject>(_ object: Object.Type) async throws {
        let name = className(object)
        if await registeredClasses.contains(name) { return }
        
        try await Interpreter.run("""
        class \(name):
            def __init__(self, address: int):
                self._address = address
        """)
        
        await MainActor.run {
            Interpreter.log.info("Registered binding: \(name)")
            _ = registeredClasses.insert(name)
        }
    }
    
    static var registry = [Int : PythonBinding]()
    @MainActor
    static var registeredClasses = Set<String>()
}

public enum PythonBindingError: Error {
    case instanceDeallocated
}
