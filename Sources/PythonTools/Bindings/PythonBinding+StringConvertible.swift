//
//  PythonBinding+StringConvertible.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-17.
//

public extension PythonBindable {
    static func setDescription<Value>(of path: KeyPath<Self, Value>) async throws {
        try await withPythonClass { pythonClass in
            pythonClass.__str__ = .instanceFunction { (obj: Self) in
                String(describing: obj[keyPath: path])
            }
        }
    }
    
    static func setDescription<Value>(of path: KeyPath<Self, Value?>) async throws {
        try await withPythonClass { pythonClass in
            pythonClass.__str__ = .instanceFunction { (obj: Self) in
                if let value = obj[keyPath: path] {
                    String(describing: value)
                } else {
                    String(describing: obj[keyPath: path])
                }
            }
        }
    }
    
    static func setDescription() async throws {
        try await setDescription(of: \.self)
    }
    
    static func setDescription<Value>() async throws where Self: PythonValueBindable<Value> {
        try await withPythonClass { pythonClass in
            pythonClass.__str__ = .instanceFunction { (obj: Self) in
                let value = obj.get()
                if let value {
                    return String(describing: value)
                } else {
                    return String(describing: value)
                }
            }
        }
    }
}
