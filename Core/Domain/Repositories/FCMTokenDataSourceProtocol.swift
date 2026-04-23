import Foundation

/// Protocol for reading and writing FCM (Firebase Cloud Messaging) token in local storage.
/// Used by AppDelegate to store token and by ViewModels to build payloads.
protocol FCMTokenDataSourceProtocol: AnyObject {

    /// Current FCM token used for push notifications.
    var token: String? { get set }

    /// APNS registration status used for startup diagnostics.
    var apnsStatus: String { get set }

    /// Latest APNS registration error description, if any.
    var apnsErrorDescription: String? { get set }

    /// Current UIApplication registration flag for remote notifications.
    var isRegisteredForRemoteNotifications: Bool { get set }

    /// Current user notification authorization status.
    var notificationAuthorizationStatus: String { get set }
}
