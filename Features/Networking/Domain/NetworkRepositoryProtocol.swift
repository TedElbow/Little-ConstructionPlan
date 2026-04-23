import Foundation

/// Protocol for network/API operations.
/// Allows swapping implementations for tests or different backends.
protocol NetworkRepositoryProtocol: AnyObject {

    /// Sends payload to server and returns web URL from response.
    /// - Parameters:
    ///   - payload: Full request body (conversion data + device/config fields).
    ///   - timeout: Request timeout in seconds.
    /// - Returns: Parsed config result (`url` + optional `expires`) from backend response.
    func fetchConfig(usingPayload payload: [AnyHashable: Any], timeout: TimeInterval) async throws -> ConfigFetchResult
}
