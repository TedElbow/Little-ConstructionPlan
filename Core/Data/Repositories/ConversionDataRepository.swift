import Foundation

/// Repository that provides conversion data from local storage, waiting until data becomes available.
/// Implements ConversionDataRepositoryProtocol for use by FetchConversionDataUseCase.
final class ConversionDataRepository: ConversionDataRepositoryProtocol {

    private let conversionDataSource: ConversionDataSourceProtocol
    private let logger: Logging
    private let waitTimeoutNanoseconds: UInt64
    private let pollIntervalNanoseconds: UInt64

    init(
        conversionDataSource: ConversionDataSourceProtocol,
        logger: Logging,
        waitTimeout: TimeInterval = 3.0,
        pollInterval: TimeInterval = 0.2
    ) {
        self.conversionDataSource = conversionDataSource
        self.logger = logger
        self.waitTimeoutNanoseconds = max(0, UInt64(waitTimeout * 1_000_000_000))
        self.pollIntervalNanoseconds = max(1_000_000, UInt64(pollInterval * 1_000_000_000))
    }

    func getConversionData() async -> [AnyHashable: Any] {
        let startedAt = Date()
        let timeoutSeconds = TimeInterval(waitTimeoutNanoseconds) / 1_000_000_000
        logger.log("ConversionDataRepository: waiting for conversion data (timeout: \(timeoutSeconds)s)")
        while conversionDataSource.conversionData == nil {
            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed >= timeoutSeconds {
                logger.log(
                    "ConversionDataRepository: timeout waiting for conversion data (\(timeoutSeconds)s), continuing with empty payload"
                )
                return [:]
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        let conversionData = conversionDataSource.conversionData ?? [:]
        if conversionData.isEmpty {
            logger.log("ConversionDataRepository: conversion data arrived but payload is empty")
        } else {
            logger.log("ConversionDataRepository: received conversion data with \(conversionData.count) keys")
        }
        return conversionData
    }
}
