import Foundation
import Combine

/// Local data source for AppsFlyer conversion data. Exposes observable state and conforms to
/// ConversionDataSinkProtocol for writes and ConversionDataSourceProtocol for reads.
/// Use via DI; no singleton.
final class ConversionDataLocalDataSource: ObservableObject, ConversionDataSinkProtocol, ConversionDataSourceProtocol {

    /// Current conversion data received from AppsFlyer. Published to notify subscribers.
    @Published private(set) var conversionData: [AnyHashable: Any]?

    private let logger: Logging

    init(logger: Logging) {
        self.logger = logger
        #if DEBUG
        conversionData = nil
        #endif
    }

    // MARK: - ConversionDataSinkProtocol

    func updateConversionData(_ data: [AnyHashable: Any]) {
        var merged = conversionData ?? [:]
        for (k, v) in data { merged[k] = v }
        conversionData = merged
        logger.log("ConversionDataLocalDataSource updated: \(merged)")
    }

    /// Clears all stored conversion data and notifies subscribers.
    func clear() {
        conversionData = nil
    }
}
