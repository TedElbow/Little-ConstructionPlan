import Foundation

/// Protocol for providing conversion/attribution data (e.g. from AppsFlyer).
/// Allows waiting for data with timeout and swapping implementations for tests.
protocol ConversionDataRepositoryProtocol: AnyObject {

    /// Returns conversion data when it becomes available.
    /// - Returns: Conversion data dictionary.
    func getConversionData() async -> [AnyHashable: Any]
}
