import Foundation
import Combine

/// Stores application logs in memory and persists them to a file.
/// Provides observable log updates for UI or debugging tools.
/// Conforms to LogStorageProtocol; create via DI container and inject where needed. No singleton.
final class LogStore: ObservableObject, LogStorageProtocol {

    /// In-memory collection of log lines.
    @Published private(set) var lines: [String] = []

    private let fileURL: URL

    /// Initializes log storage, resolves file path, and loads existing logs from disk.
    init() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("app_logs.txt")
        loadFromFile()
    }

    /// Loads existing log lines from the persistent file into memory.
    private func loadFromFile() {
        if let data = try? Data(contentsOf: fileURL),
           let content = String(data: data, encoding: .utf8) {
            lines = content.components(separatedBy: .newlines)
        }
    }

    /// Appends a new log message with timestamp, updates observers, and persists logs to file.
    func append(message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)"
        DispatchQueue.main.async {
            self.lines.append(line)
            self.trimIfNeeded()
            self.saveToFile()
        }
    }

    /// Ensures the in-memory log buffer does not exceed the maximum allowed number of entries.
    private func trimIfNeeded() {
        if lines.count > 2000 {
            lines.removeFirst(lines.count - 2000)
        }
    }

    /// Saves the current in-memory log lines to the persistent log file.
    private func saveToFile() {
        let content = lines.joined(separator: "\n")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
        }
    }

    /// Clears all in-memory logs and removes the persistent log file.
    func clear() {
        lines = []
        try? FileManager.default.removeItem(at: fileURL)
    }
}
