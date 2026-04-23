import Foundation

/// Protocol for app initialization use case. Used by AppViewModel and DI.
/// Feature contract: run startup flow and resolve target app state.
protocol AppInitializerUseCaseProtocol: AnyObject {
    /// Latest startup diagnostics captured during the last `execute` call.
    var latestDiagnostics: StartupDiagnostics { get }

    /// Runs the full startup flow and returns the target app state.
    /// - Parameters:
    ///   - pushToken: FCM push token if available.
    ///   - hasLaunchedBefore: Whether the user has launched the app before.
    /// - Returns: Resolved `AppState` for UI navigation.
    func execute(pushToken: String?, hasLaunchedBefore: Bool) async -> AppState
}
