import Foundation

/// Domain entity for the backend server response after sending conversion payload.
struct ServerResponse {
    /// Whether the request was successful.
    let success: Bool
    /// Web URL to open, if provided by server.
    let url: URL?

    init(success: Bool, url: URL? = nil) {
        self.success = success
        self.url = url
    }

    /// Creates entity from parsed JSON response.
    init?(json: [String: Any]) {
        let ok = json["ok"] as? Bool ?? false
        let urlString = json["url"] as? String
        self.success = ok
        self.url = urlString.flatMap { URL(string: $0) }
    }
}
