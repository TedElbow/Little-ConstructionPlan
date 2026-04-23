import Foundation

/// Protocol for analytics (e.g. AppsFlyer) integration.
/// Allows swapping implementations for tests or different providers.
protocol AnalyticsRepositoryProtocol: AnyObject {

    /// Returns the analytics provider user ID (e.g. AppsFlyer UID) used for attribution and payloads.
    func getAnalyticsUserId() -> String?

    /// Triggers analytics SDK to refresh install/conversion attribution data.
    /// Used as a fallback when initial callback may report stale install status.
    func refreshInstallConversionData()

    /// Returns latest AppsFlyer UDL/attribution payload if available.
    func getLatestAttributionData() -> [AnyHashable: Any]

    /// Performs direct AppsFlyer install-data request (GCD SDK endpoint) using current SDK identifiers.
    /// Returns parsed JSON dictionary when request succeeds.
    func fetchInstallConversionDataSnapshot() async -> [AnyHashable: Any]?
}
