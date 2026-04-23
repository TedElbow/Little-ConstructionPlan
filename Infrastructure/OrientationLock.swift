import UIKit

/// Provides helper methods to control and enforce application interface orientation.
struct OrientationLock {

    /// Locks the application to the specified interface orientation mask.
    static func lock(_ orientation: UIInterfaceOrientationMask) {
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.orientationLock = orientation
        }
    }

    /// Locks the application to portrait orientation and forces device orientation update.
    static func lockPortrait() {
        lock(.portrait)
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }
}
