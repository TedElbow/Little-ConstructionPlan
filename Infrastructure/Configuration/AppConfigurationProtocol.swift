import Foundation

/// Protocol for application configuration. Allows swapping implementations per build configuration or environment.
protocol AppConfigurationProtocol: AnyObject {
    // Server & identifiers
    var serverURL: String { get }
    var storeId: String { get }
    var firebaseProjectId: String { get }
    var appsFlyerDevKey: String { get }
    var storeIdWithPrefix: String { get }

    // UI / copy
    var os: String { get }
    var noInternetMessage: String { get }
    var notificationSubtitle: String { get }
    var notificationDescription: String { get }

    // Debug / feature flags
    var isDebug: Bool { get }
    var isGameOnly: Bool { get }
    var isWebOnly: Bool { get }
    var isNoNetwork: Bool { get }
    var isAskNotifications: Bool { get }
    var isInfinityLoading: Bool { get }
    var isForceOpenTestState: Bool { get }
}
