import Foundation

/// Stores and resolves repeat schedule for ask notifications screen after user skips it.
enum AskNotificationsRepeatState {
    private static let lastSkipAtKey = "ask_notifications_last_skip_at"
    private static let repeatPendingKey = "ask_notifications_repeat_pending"
    private static let repeatDelay: TimeInterval = 3 * 24 * 60 * 60
    static var userDefaults: UserDefaults = .standard

    static func markSkipped(now: Date = Date(), defaults: UserDefaults = AskNotificationsRepeatState.userDefaults) {
        defaults.set(now.timeIntervalSince1970, forKey: lastSkipAtKey)
        defaults.set(true, forKey: repeatPendingKey)
    }

    static func shouldShowRepeat(now: Date = Date(), defaults: UserDefaults = AskNotificationsRepeatState.userDefaults) -> Bool {
        guard defaults.bool(forKey: repeatPendingKey) else { return false }
        let timestamp = defaults.double(forKey: lastSkipAtKey)
        guard timestamp > 0 else { return false }
        let nextAllowedDate = Date(timeIntervalSince1970: timestamp).addingTimeInterval(repeatDelay)
        return now >= nextAllowedDate
    }

    static func clearPending(defaults: UserDefaults = AskNotificationsRepeatState.userDefaults) {
        defaults.set(false, forKey: repeatPendingKey)
    }

    /// Updates repeat schedule based on system push permission result.
    static func handleAuthorizationResult(
        granted: Bool,
        now: Date = Date(),
        defaults: UserDefaults = AskNotificationsRepeatState.userDefaults
    ) {
        if granted {
            clearPending(defaults: defaults)
        } else {
            markSkipped(now: now, defaults: defaults)
        }
    }
}
