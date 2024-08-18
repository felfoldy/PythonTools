//
//  DeinitObserver.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-18.
//

import Foundation

/// This is a simple object whose job is to execute
/// some closure when it deinitializes
class DeinitializationObserver {

    let execute: () -> ()

    init(execute: @escaping () -> ()) {
        self.execute = execute
    }

    deinit {
        execute()
    }
}

/// We're using objc associated objects to have this `DeinitializationObserver`
/// stored inside the protocol extension
private struct AssociatedKeys {
    static var DeinitializationObserver = "DeinitializationObserver"
}

/// Protocol for any object that implements this logic
public protocol ObservableDeinitialization: AnyObject {
    func onDeinit(_ execute: @escaping () -> ())
}

extension ObservableDeinitialization {
    /// This stores the `DeinitializationObserver`. It's fileprivate so you
    /// cannot interfere with this outside. Also we're using a strong retain
    /// which will ensure that the `DeinitializationObserver` is deinitialized
    /// at the same time as your object.
    fileprivate var deinitializationObserver: DeinitializationObserver {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.DeinitializationObserver) as! DeinitializationObserver
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.DeinitializationObserver,
                newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// This is what you call to add a block that should execute on `deinit`
    public func onDeinit(_ execute: @escaping () -> ()) {
        deinitializationObserver = DeinitializationObserver(execute: execute)
    }
}
