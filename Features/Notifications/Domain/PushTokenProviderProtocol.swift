import Foundation

/// Protocol for obtaining FCM push token asynchronously. Used by app initialization flow
/// so that ViewModels do not depend on Firebase directly.
protocol PushTokenProviderProtocol: AnyObject {

    /// Returns current push token if available; may request from remote service.
    /// - Returns: FCM token string or nil if not available.
    func getToken() async -> String?
}
