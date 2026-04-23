import Foundation

/// Protocol for persisted startup state storage.
protocol StartupStateStoreProtocol: AnyObject {
    var mode: StartupMode { get set }
    var isConfigRequestsDisabled: Bool { get set }
    var cachedWebConfig: CachedWebConfig? { get set }
}
