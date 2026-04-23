import Foundation

/// Persisted web config used as launch fallback.
struct CachedWebConfig: Equatable {
    let urlString: String
    let expiresAt: Date?
}
