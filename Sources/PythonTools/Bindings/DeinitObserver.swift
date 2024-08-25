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

public protocol ObservableDeinitialization: AnyObject {
    /// Execute on`deinit`.
    func onDeinit(_ execute: @escaping () -> ())
}

extension ObservableDeinitialization {
    fileprivate var deinitializationObserver: DeinitializationObserver {
        get {
            return objc_getAssociatedObject(self, "DeinitializationObserver") as! DeinitializationObserver
        }
        set {
            objc_setAssociatedObject(
                self,
                "DeinitializationObserver",
                newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    public func onDeinit(_ execute: @escaping () -> ()) {
        deinitializationObserver = DeinitializationObserver(execute: execute)
    }
}
