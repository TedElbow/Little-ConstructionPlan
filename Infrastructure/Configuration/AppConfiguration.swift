import Foundation

/// Keys for optional overrides from the app Bundle (Info.plist), e.g. via Xcode Build Settings / `INFOPLIST_KEY_*`.
enum AppConfigurationBundleKey {
    static let serverURL = "SERVER_URL"
    static let storeId = "STORE_ID"
    static let firebaseProjectId = "FIREBASE_PROJECT_ID"
    static let appsFlyerDevKey = "APPSFLYER_DEV_KEY"
    static let isDebug = "IS_DEBUG"
    static let askNotifications = "ASK_NOTIFICATIONS"
    static let testStateForceOpen = "TEST_STATE_FORCE_OPEN"
    static let forceDebugMode = "FORCE_DEBUG_MODE"
}

/// Default implementation of app configuration.
/// Bundle (Info.plist) values override `StartupDefaultsConfiguration` when present.
final class AppConfiguration: AppConfigurationProtocol {

    // MARK: - Server & identifiers (from Bundle, else defaults)

    let serverURL: String
    let storeId: String
    let firebaseProjectId: String
    let appsFlyerDevKey: String

    var storeIdWithPrefix: String {
        "id" + storeId
    }

    // MARK: - UI / copy

    let os: String
    let noInternetMessage: String
    let notificationSubtitle: String
    let notificationDescription: String

    // MARK: - Debug / feature flags

    let isDebug: Bool
    let isGameOnly: Bool
    let isWebOnly: Bool
    let isNoNetwork: Bool
    let isAskNotifications: Bool
    let isInfinityLoading: Bool
    let isForceOpenTestState: Bool

    // MARK: - Defaults (fallback when not in Bundle)

    private static let defaultServerURL = StartupDefaultsConfiguration.serverURL
    private static let defaultStoreId = StartupDefaultsConfiguration.storeId
    private static let defaultFirebaseProjectId = StartupDefaultsConfiguration.firebaseProjectId
    private static let defaultAppsFlyerDevKey = StartupDefaultsConfiguration.appsFlyerDevKey
    /// Debug builds use `true` when plist has no `IS_DEBUG`; otherwise `StartupDefaultsConfiguration.isDebug`.
    private static var defaultIsDebug: Bool {
        #if DEBUG
        return true
        #else
        return StartupDefaultsConfiguration.isDebug
        #endif
    }
    private static let defaultIsGameOnly = StartupDefaultsConfiguration.isGameOnly
    private static let defaultIsWebOnly = StartupDefaultsConfiguration.isWebOnly
    private static let defaultIsNoNetwork = StartupDefaultsConfiguration.isNoNetwork
    private static let defaultIsAskNotifications = StartupDefaultsConfiguration.isAskNotifications
    private static let defaultIsInfinityLoading = StartupDefaultsConfiguration.isInfinityLoading
    private static let defaultIsForceOpenTestState = StartupDefaultsConfiguration.isForceOpenTestState

    // MARK: - Initialization

    init(
        serverURL: String? = nil,
        storeId: String? = nil,
        firebaseProjectId: String? = nil,
        appsFlyerDevKey: String? = nil,
        os: String = "iOS",
        noInternetMessage: String = "Please, check your internet connection and restart",
        notificationSubtitle: String = "Allow notifications about bonuses and promos",
        notificationDescription: String = "Stay tuned with best offers from our casino",
        
        isDebug: Bool = AppConfiguration.defaultIsDebug,
        isGameOnly: Bool = AppConfiguration.defaultIsGameOnly,
        isWebOnly: Bool = AppConfiguration.defaultIsWebOnly,
        isNoNetwork: Bool = AppConfiguration.defaultIsNoNetwork,
        isAskNotifications: Bool? = nil,
        isInfinityLoading: Bool = AppConfiguration.defaultIsInfinityLoading,
        isForceOpenTestState: Bool? = nil,
        bundle: Bundle = .main
    ) {
        let info = bundle.infoDictionary ?? [:]
        self.serverURL = serverURL
            ?? (info[AppConfigurationBundleKey.serverURL] as? String)
            ?? Self.defaultServerURL
        self.storeId = storeId
            ?? (info[AppConfigurationBundleKey.storeId] as? String)
            ?? Self.defaultStoreId
        self.firebaseProjectId = firebaseProjectId
            ?? (info[AppConfigurationBundleKey.firebaseProjectId] as? String)
            ?? Self.defaultFirebaseProjectId
        self.appsFlyerDevKey = appsFlyerDevKey
            ?? (info[AppConfigurationBundleKey.appsFlyerDevKey] as? String)
            ?? Self.defaultAppsFlyerDevKey
        self.os = os
        self.noInternetMessage = noInternetMessage
        self.notificationSubtitle = notificationSubtitle
        self.notificationDescription = notificationDescription
        self.isDebug = Self.resolveBoolValue(
            infoValue: info[AppConfigurationBundleKey.isDebug],
            fallback: isDebug
        )
        self.isGameOnly = isGameOnly
        self.isWebOnly = isWebOnly
        self.isNoNetwork = isNoNetwork
        self.isAskNotifications = isAskNotifications ?? Self.resolveBoolValue(
            infoValue: info[AppConfigurationBundleKey.askNotifications],
            fallback: Self.defaultIsAskNotifications
        )
        self.isInfinityLoading = isInfinityLoading
        self.isForceOpenTestState = isForceOpenTestState ?? Self.resolveBoolValue(
            infoValue: info[AppConfigurationBundleKey.testStateForceOpen],
            fallback: Self.resolveBoolValue(
                infoValue: info[AppConfigurationBundleKey.forceDebugMode],
                fallback: Self.defaultIsForceOpenTestState
            )
        )
    }

    private static func resolveBoolValue(infoValue: Any?, fallback: Bool) -> Bool {
        guard let infoValue else { return fallback }
        if let boolValue = infoValue as? Bool {
            return boolValue
        }
        if let numberValue = infoValue as? NSNumber {
            return numberValue.boolValue
        }
        if let stringValue = infoValue as? String {
            let normalized = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch normalized {
            case "1", "true", "yes", "on":
                return true
            case "0", "false", "no", "off":
                return false
            default:
                return fallback
            }
        }
        return fallback
    }
}
