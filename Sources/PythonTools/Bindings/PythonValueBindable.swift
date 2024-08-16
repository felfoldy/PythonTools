//
//  PythonValueBindable.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-15.
//

open class PythonValueBindable<Value> {
    public let get: () -> Value?
    public let set: ((Value?) -> Void)?
    
    public var value: Value? {
        get { get() }
        set { set?(newValue) }
    }
    
    required public init(get: @escaping () -> Value?, set: @escaping (Value?) -> Void) {
        self.get = get
        self.set = set
    }

    required public init<Base: AnyObject>(base: Base, path: KeyPath<Base, Value>) {
        Interpreter.log.debug("Value binding created: \(String(describing: path))")

        get = { [weak base] in
            base?[keyPath: path]
        }
        
        if let writablePath = path as? WritableKeyPath<Base, Value> {
            set = { [weak base] newValue in
                if let newValue {
                    base?[keyPath: writablePath] = newValue
                }
            }
        } else {
            set = nil
        }
    }

    required public init<Base: AnyObject>(base: Base, path: KeyPath<Base, Value?>) {
        Interpreter.log.debug("Value binding created: \(String(describing: path))")
        
        get = { [weak base] in
            base?[keyPath: path]
        }
        
        if let writablePath = path as? WritableKeyPath<Base, Value?> {
            set = { [weak base] newValue in
                base?[keyPath: writablePath] = newValue
            }
        } else {
            set = nil
        }
    }
    
    deinit {
        Interpreter.log.debug("Value binding deleted")
    }
}
