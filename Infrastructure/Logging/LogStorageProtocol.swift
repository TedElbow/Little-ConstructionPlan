import Foundation

/// Protocol for log storage. Allows appending messages and reading stored lines.
/// Used by the logger implementation and by debug UI (e.g. console view).
/// Inject via DI so tests can substitute with a mock.
protocol LogStorageProtocol: AnyObject {

    /// Appends a new log line (implementation may add timestamp and persist).
    func append(message: String)

    /// Current log lines for display or export.
    var lines: [String] { get }
}
