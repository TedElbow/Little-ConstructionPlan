import Foundation

/// Protocol for receiving conversion/attribution data updates (e.g. from AppsFlyer delegate callbacks).
/// Allows repository to update storage without depending on concrete type; enables testing.
protocol ConversionDataSinkProtocol: AnyObject {

    /// Merges new conversion data into storage and notifies subscribers.
    /// - Parameter data: New conversion data to merge.
    func updateConversionData(_ data: [AnyHashable: Any])
}
