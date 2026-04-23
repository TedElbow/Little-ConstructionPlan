import Foundation

/// Resolves current build configuration from compile-time flags set by Xcode Build Configurations.
/// Use Debug / Release / Staging scheme or build setting to switch.
/// Each derived app can override values via build settings or AppConfiguration.
enum BuildConfiguration {

    case debug
    case release
    case staging

    /// Current configuration resolved from SWIFT_ACTIVE_COMPILATION_CONDITIONS (DEBUG, STAGING).
    static var current: BuildConfiguration {
        #if DEBUG
        return .debug
        #elseif STAGING
        return .staging
        #else
        return .release
        #endif
    }

    var isDebug: Bool { self == .debug }
    var isStaging: Bool { self == .staging }
    var isRelease: Bool { self == .release }
}
