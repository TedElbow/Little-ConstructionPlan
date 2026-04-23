import Foundation

/// Domain entity for attribution/conversion data (e.g. from AppsFlyer).
/// Wraps key-value data while keeping compatibility with existing dictionary-based APIs.
struct ConversionData {
    /// Raw key-value representation for payload building and storage.
    private(set) var raw: [String: Any]

    init(raw: [String: Any] = [:]) {
        self.raw = raw
    }

    /// Creates entity from AppsFlyer-style dictionary (AnyHashable keys).
    init(from dictionary: [AnyHashable: Any]) {
        var result: [String: Any] = [:]
        for (key, value) in dictionary {
            if let k = key as? String {
                result[k] = value
            }
        }
        self.raw = result
    }

    /// Conversion status (e.g. "Organic", "Non-organic").
    var afStatus: String? {
        raw["af_status"] as? String
    }

    /// Exposes raw dictionary for serialization and API payloads.
    func toDictionary() -> [String: Any] {
        raw
    }
}
