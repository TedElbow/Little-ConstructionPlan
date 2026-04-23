import Foundation

/// Registers hosts discovered during config handling for App Transport Security exception domains.
protocol AppTransportSecurityHostRegistrarProtocol: Sendable {
    /// Called when the config response is processed; supplies the web URL from the payload (if any),
    /// the config endpoint URL used for the request, and optional cache expiry from the response.
    func registerHostsFromConfigResponse(webURL: URL?, configRequestURL: URL?, expiresAt: Date?) async
}
