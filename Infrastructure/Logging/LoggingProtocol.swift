import Foundation

/// Log level for filtering and routing. Kept separate from OSLog to avoid coupling.
enum LogLevel {
    case debug
    case info
    case error
    case fault
}

/// Protocol for application logging. Use this in types that need to log; inject via DI for testability.
protocol Logging: AnyObject {

    /// Logs a message with the given level.
    func log(_ message: String, level: LogLevel)
}

extension Logging {

    /// Logs a message at default (info) level.
    func log(_ message: String) {
        log(message, level: .info)
    }
}
