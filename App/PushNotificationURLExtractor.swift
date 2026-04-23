import Foundation

/// Extracts a deep-link URL string from push notification `userInfo` (FCM / Leanplum / custom data).
/// Key order matches server-side URL resolution where applicable (`url` → `deep_link` → `link`).
enum PushNotificationURLExtractor {

    /// Top-level keys checked in strict priority order (first non-empty string wins).
    private static let orderedTopLevelKeys: [String] = [
        "url",
        "deep_link",
        "link",
        "target",
        "redirect",
        "browser_fallback_url",
        "fallback_url",
        "click_action",
        "clickAction",
        "OpenUrl",
        "open_url",
        "openUrl",
        "gcm.notification.link"
    ]

    /// Keys inside nested `gcm.notification` dictionary.
    private static let gcmNotificationKeys: [String] = [
        "url",
        "deep_link",
        "link",
        "click_action",
        "clickAction"
    ]

    /// Keys inside nested `fcm_options` dictionary (when sent as a dictionary).
    private static let fcmOptionsKeys: [String] = [
        "url",
        "deep_link",
        "link"
    ]

    /// Returns a URL suitable for `DeepLinkRouter.handleIncomingURL(_:)` if a candidate is found.
    static func urlForDeepLinkRouting(from userInfo: [AnyHashable: Any]) -> URL? {
        for raw in candidateStrings(from: userInfo) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let incomingURL = URL(string: trimmed) else { continue }
            if let resolved = DeepLinkRouter.resolveIncomingURL(incomingURL) {
                return resolved
            }
        }
        return nil
    }

    static func firstURLString(from userInfo: [AnyHashable: Any]) -> String? {
        return candidateStrings(from: userInfo).first
    }

    private static func candidateStrings(from userInfo: [AnyHashable: Any]) -> [String] {
        var candidates: [String] = []
        for key in orderedTopLevelKeys {
            if let value = stringValue(forKey: key, in: userInfo) {
                candidates.append(value)
            }
        }
        if let gcm = dictionaryValue(forKey: "gcm.notification", in: userInfo) {
            for key in gcmNotificationKeys {
                if let value = stringValue(forKey: key, in: gcm) {
                    candidates.append(value)
                }
            }
        }
        if let options = dictionaryValue(forKey: "fcm_options", in: userInfo) {
            for key in fcmOptionsKeys {
                if let value = stringValue(forKey: key, in: options) {
                    candidates.append(value)
                }
            }
        }
        return candidates
    }

    private static func stringValue(forKey key: String, in dict: [AnyHashable: Any]) -> String? {
        guard let raw = dict[AnyHashable(key)] else { return nil }
        if let s = raw as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if let n = raw as? NSNumber {
            return n.stringValue
        }
        return nil
    }

    private static func dictionaryValue(forKey key: String, in dict: [AnyHashable: Any]) -> [AnyHashable: Any]? {
        guard let raw = dict[AnyHashable(key)] else { return nil }
        return dictionaryFromAny(raw)
    }

    private static func dictionaryFromAny(_ raw: Any) -> [AnyHashable: Any]? {
        if let d = raw as? [AnyHashable: Any] {
            return d
        }
        if let d = raw as? [String: Any] {
            var out: [AnyHashable: Any] = [:]
            for (k, v) in d {
                out[AnyHashable(k)] = v
            }
            return out
        }
        return nil
    }
}
