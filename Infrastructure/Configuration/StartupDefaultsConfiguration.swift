import Foundation

/// Centralized startup defaults for runtime configuration (URLs, store/API identifiers, feature flags).
/// Edit these values per app clone; `AppConfiguration` uses them when Bundle/Info.plist keys are absent.
enum StartupDefaultsConfiguration {
    /// Example: "https://example.com/config.php"
    static let serverURL = "https://moodpatth.com/config.php"
    /// Example: "1234567890"
    static let storeId = "6763045346"
    /// Example: "123456789012"
    static let firebaseProjectId = "723028955684"
    /// Example: "AbCdEfGhIjKlMnOpQrStUv"
    static let appsFlyerDevKey = "BJbTQ2FWf4HbxexYxodCNF"

    /// Example: true for debug diagnostics builds.
    static let isDebug = true
    /// Example: true to always open game content.
    static let isGameOnly = true
    /// Example: true to always force web flow.
    static let isWebOnly = false
    /// Example: true to simulate no network startup.
    static let isNoNetwork = false
    /// Example: true to force notifications pre-screen.
    static let isAskNotifications = false
    /// Example: true to keep the app in loading state.
    static let isInfinityLoading = false
    /// Example: true to force opening test startup branch.
    static let isForceOpenTestState = false
    
    // MARK: - Simulating a remote push (Simulator, command line)
    //
    // 1. Run the app on a booted Simulator (any iOS sim).
    // 2. Create a small JSON file, e.g. `push.apns`, with an `aps` payload (and optional custom keys your app reads).
    // 3. From Terminal:
    //
    //    xcrun simctl push booted <MAIN_APP_BUNDLE_ID> /absolute/path/to/push.apns
    //
    //    Use the **main app** bundle id from Xcode (Signing & Capabilities), not the notifications extension.
    //    Replace `booted` with a specific UDID from `xcrun simctl list devices` if several sims are running.
    //
    // Minimal example `push.apns` body:
    // { "aps": { "alert": { "title": "Test", "body": "Hello" }, "sound": "default" } }
    //
    // For deep links / data, add keys at the top level of the JSON that match what your `AppDelegate` / notification handlers expect.
    
    
    // xcrun simctl push booted <BUNDLE ID> <PUSH FILE PATH.apns>
    // xcrun simctl push booted com.DavidRoberts.LittleStreakUp /Users/otodr/Work/src/IOS-CluckyNumbers/push1.apns
    
   
    // xcrun simctl push booted com.DavidRoberts.LittleStreakUp /Users/otodr/Work/src/IOS-Test/push2.apns
}
