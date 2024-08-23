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

public protocol ObservableDeinitialization: AnyObject {
    /// Execute on`deinit`.
    func onDeinit(_ execute: @escaping () -> ())
}

extension ObservableDeinitialization {
    fileprivate var deinitializationObserver: DeinitializationObserver {
        get {
            return objc_getAssociatedObject(self, AssociatedKeys.DeinitializationObserver) as! DeinitializationObserver
        }
        set {
            objc_setAssociatedObject(
                self,
                AssociatedKeys.DeinitializationObserver,
                newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    public func onDeinit(_ execute: @escaping () -> ()) {
        deinitializationObserver = DeinitializationObserver(execute: execute)
    }
}
