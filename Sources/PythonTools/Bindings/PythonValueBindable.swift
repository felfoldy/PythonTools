//
//  PythonValueBindable.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-15.
//

public typealias PythonValueBindable<Value> = PythonValueReference<Value> & PythonBindable

open class PythonValueReference<Value> {
    public let get: () -> Value?
    public let set: ((Value?) -> Void)?
    
    public var value: Value! {
        get { get() }
        set { set?(newValue) }
    }

    required public init<Base: AnyObject>(base: Base, path: KeyPath<Base, Value>) {
        get = { [weak base] in
            base?[keyPath: path]
        }
        
        if let writablePath = path as? WritableKeyPath {
            set = { [weak base] newValue in
                if let newValue {
                    base?[keyPath: writablePath] = newValue
                }
            }
        } else {
            set = nil
        }
    }
}

// MARK: - Property registration

extension PropertyRegistration {
    /// Value binding with optional path.
    public static func value<Element, Binding>(
        _ name: String,
        _ path: KeyPath<Root, Element>,
        as type: Binding.Type
    ) -> PropertyRegistration<Root> where Binding: PythonValueBindable<Element>,
                                          Binding: PythonBindable {
        cache(name) { (root: Root) in
            Binding(base: root, path: path)
        }
    }
}
