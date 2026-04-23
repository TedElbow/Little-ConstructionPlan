import Foundation

/// Protocol for fetching conversion data. Used by initialization flow and tests.
protocol FetchConversionDataUseCaseProtocol: AnyObject {

    /// Fetches conversion data and waits until data is available.
    /// - Returns: Conversion data dictionary (e.g. from AppsFlyer).
    func execute() async -> [AnyHashable: Any]
}

/// Use case: obtain attribution/conversion data (e.g. from AppsFlyer).
final class FetchConversionDataUseCase: FetchConversionDataUseCaseProtocol {

    private let conversionDataRepository: ConversionDataRepositoryProtocol

    init(conversionDataRepository: ConversionDataRepositoryProtocol) {
        self.conversionDataRepository = conversionDataRepository
    }

    func execute() async -> [AnyHashable: Any] {
        await conversionDataRepository.getConversionData()
    }
}
