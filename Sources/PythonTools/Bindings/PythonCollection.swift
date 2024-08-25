//
//  PythonCollection.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-14.
//

import PythonKit

@MainActor
public final class PythonCollection<Base: PythonBindable, Value: Collection> where Value.Element: PythonConvertible, Value.Index: ConvertibleFromPython {
    weak var base: Base?
    let path: KeyPath<Base, Value>
    
    public init(base: Base, path: KeyPath<Base, Value>) {
        self.base = base
        self.path = path
    }
    
    func getter() -> Value? {
        base?[keyPath: path]
    }
    
    var writablePath: WritableKeyPath<Base, Value>? {
        path as? WritableKeyPath<Base, Value>
    }
}

extension PythonCollection: PythonBindable {
    public static var pythonClassName: String {
        "\(Base.pythonClassName)_\(String(describing: Value.self))_Collection"
    }
    
    public static func register() throws {
        try PythonBinding.register(PythonCollection.self, subclass: "SwiftManagedCollection", members: [])
        
        try withPythonClass { pythonClass in
            pythonClass.__len__ = .instanceFunction { (collection: Self) in
                collection.getter()?.count
            }
            
            pythonClass.__getitem__ = .instanceFunction { (collection: Self, idx) in
                collection.getter()?[Value.Index(idx)!]
            }
        }
    }
}
