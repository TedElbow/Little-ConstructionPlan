import Foundation

/// Result model from config endpoint request.
struct ConfigFetchResult: Equatable {
    let urlString: String?
    let expiresAt: Date?
}
