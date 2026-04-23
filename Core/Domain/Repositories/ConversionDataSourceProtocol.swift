import Foundation

/// Protocol for reading conversion/attribution data from local storage.
/// Used by repositories and use cases to obtain data written by analytics (e.g. AppsFlyer).
protocol ConversionDataSourceProtocol: AnyObject {

    /// Current conversion data if available; nil until first update.
    var conversionData: [AnyHashable: Any]? { get }
}
