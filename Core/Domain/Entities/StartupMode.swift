import Foundation

/// Persisted launch mode resolved during startup flow.
enum StartupMode: String {
    case unresolved
    case web
    case native

    /// Decodes stored value; migrates legacy `"game"` to `.native`.
    static func fromStoredRawValue(_ raw: String?) -> StartupMode {
        guard let raw, !raw.isEmpty else { return .unresolved }
        if raw == "game" {
            return .native
        }
        return StartupMode(rawValue: raw) ?? .unresolved
    }
}
