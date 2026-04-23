import Foundation

/// Represents all possible high-level application states used to drive UI navigation.
enum AppState: Equatable {
    /// Initial loading state while attribution and config are being resolved.
    case loading
    /// Native app shell (template main content; extend in the host app).
    case native
    /// Diagnostic startup screen with stage-by-stage status and details.
    case testState(StartupDiagnostics)
    /// User should see WebView with the given URL.
    case web(URL)
    /// First launch flow with optional URL for post-onboarding.
    case firstLaunch(URL)
    /// Prompt for notification permission before showing content at URL.
    case askNotifications(URL)
    /// Application error with user-facing message.
    case error(String)
    /// No network connectivity.
    case noInternet
}
