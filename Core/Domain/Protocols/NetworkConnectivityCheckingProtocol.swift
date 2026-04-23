import Foundation

/// Reports whether the device currently has a network path suitable for reaching the internet.
protocol NetworkConnectivityCheckingProtocol: Sendable {
    func isNetworkReachable() async -> Bool
}

/// Optimistic default for tests; production should inject a path-based checker.
struct AssumeNetworkReachableConnectivityChecker: NetworkConnectivityCheckingProtocol {
    func isNetworkReachable() async -> Bool { true }
}
