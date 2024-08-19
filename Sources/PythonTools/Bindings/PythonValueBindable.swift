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
    
    @available(*, deprecated)
    public var value: Value! {
        get { get() }
        set { set?(newValue) }
    }
    
    required public init(get: @escaping () -> Value?, set: ((Value?) -> Void)?) {
        self.get = get
        self.set = set
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
    public static func set<WrappedRoot, Value>(
        _ name: String,
        _ path: KeyPath<WrappedRoot, Value>
    ) -> PropertyRegistration
    where Value: Registerable, Root: PythonValueBindable<WrappedRoot> {
        .bind(
            name: name,
            get: { reference in
                reference.get()?[keyPath: path]
            },
            set: { () -> ((inout Root, Value?) -> Void)? in
                guard let path = path as? WritableKeyPath else {
                    return nil
                }
                
                return { (reference, value) in
                    guard let value else { return }
                    var wrapped = reference.get()
                    wrapped?[keyPath: path] = value
                    reference.set?(wrapped)
                }
            }()
        )
    }
    
    /// Value binding.
    public static func value<Element, Binding>(
        _ name: String,
        _ path: KeyPath<Root, Element>,
        as type: Binding.Type
    ) -> PropertyRegistration<Root> where Binding: PythonValueBindable<Element> {
        cache(name) { (root: Root) in
            Binding(base: root, path: path)
        }
    }
    
    /// Value binding.
    public static func value<WrappedRoot, Element, Binding>(
        _ name: String,
        _ path: KeyPath<WrappedRoot, Element>,
        as type: Binding.Type
    ) -> PropertyRegistration<Root> where Binding: PythonValueBindable<Element>,
                                          Root: PythonValueBindable<WrappedRoot> {
        cache(name) { (root: Root) in
            Binding(
                get: { [weak root] in
                    root?.get()?[keyPath: path]
                },
                set: { [weak root] in
                    guard let path = path as? WritableKeyPath else {
                        return nil
                    }
                    
                    return { newValue in
                        guard let newValue else { return }
                        var wrapped = root?.get()
                        wrapped?[keyPath: path] = newValue
                        root?.set?(wrapped)
                    }
                }()
            )
        }
    }
}
