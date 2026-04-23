import Foundation
import os

/// Default logging implementation: writes to OSLog and appends to the injected log storage.
final class DefaultLogger: Logging {

    private let subsystem: String
    private let category: String
    private let storage: LogStorageProtocol
    private let isEnabled: Bool
    private lazy var osLogger = Logger(subsystem: subsystem, category: category)

    init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "LittleConstructionPlan",
        category: String = "App",
        storage: LogStorageProtocol,
        isEnabled: Bool = true
    ) {
        self.subsystem = subsystem
        self.category = category
        self.storage = storage
        self.isEnabled = isEnabled
    }

    func log(_ message: String, level: LogLevel = .info) {
        let levelLabel: String
        switch level {
        case .debug:
            levelLabel = "DEBUG"
        case .error:
            levelLabel = "ERROR"
        case .fault:
            levelLabel = "FAULT"
        case .info:
            levelLabel = "INFO"
        }

        // Always print to Xcode console so runtime flow can be observed in any build configuration.
        print("[\(category)][\(levelLabel)] \(message)")

        guard isEnabled else { return }
        switch level {
        case .debug:
            osLogger.debug("\(message)")
        case .error:
            osLogger.error("\(message)")
        case .fault:
            osLogger.fault("\(message)")
        case .info:
            osLogger.log("\(message)")
        }
        storage.append(message: message)
    }
}
