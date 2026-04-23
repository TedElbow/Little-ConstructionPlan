import Foundation
import Network

/// Uses `NWPathMonitor` for a one-shot reachability snapshot at call time.
struct NWPathNetworkConnectivityChecker: NetworkConnectivityCheckingProtocol {
    func isNetworkReachable() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.DavidRoberts.LittleStreakUp.networkConnectivity")
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: queue)
        }
    }
}
