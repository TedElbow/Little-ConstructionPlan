import Foundation

/// UserDefaults-backed startup state storage.
final class StartupStateStore: StartupStateStoreProtocol {
    private enum Key {
        static let mode = "startup_mode"
        static let isConfigRequestsDisabled = "startup_config_requests_disabled"
        static let cachedURL = "startup_cached_web_url"
        static let cachedExpiresAt = "startup_cached_web_expires_at"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var mode: StartupMode {
        get {
            StartupMode.fromStoredRawValue(defaults.string(forKey: Key.mode))
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.mode)
        }
    }

    var isConfigRequestsDisabled: Bool {
        get { defaults.bool(forKey: Key.isConfigRequestsDisabled) }
        set { defaults.set(newValue, forKey: Key.isConfigRequestsDisabled) }
    }

    var cachedWebConfig: CachedWebConfig? {
        get {
            guard let urlString = defaults.string(forKey: Key.cachedURL),
                  !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            let expiresAt = defaults.object(forKey: Key.cachedExpiresAt) as? Date
            return CachedWebConfig(urlString: urlString, expiresAt: expiresAt)
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: Key.cachedURL)
                defaults.removeObject(forKey: Key.cachedExpiresAt)
                return
            }
            defaults.set(newValue.urlString, forKey: Key.cachedURL)
            defaults.set(newValue.expiresAt, forKey: Key.cachedExpiresAt)
        }
    }
}
