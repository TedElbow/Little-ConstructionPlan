import Foundation
import AppsFlyerLib

/// AppsFlyer analytics repository: implements AnalyticsRepositoryProtocol and AppsFlyerLibDelegate.
/// Handles conversion/attribution callbacks and forwards them to the injected sink; use via DI.
final class AppsFlyerRepository: NSObject, AnalyticsRepositoryProtocol, AppsFlyerLibDelegate {

    private let conversionDataSink: ConversionDataSinkProtocol
    private let logger: Logging
    private var latestAttributionData: [AnyHashable: Any] = [:]

    init(conversionDataSink: ConversionDataSinkProtocol, logger: Logging) {
        self.conversionDataSink = conversionDataSink
        self.logger = logger
        super.init()
    }

    // MARK: - AnalyticsRepositoryProtocol

    func getAnalyticsUserId() -> String? {
        AppsFlyerLib.shared().getAppsFlyerUID()
    }

    func refreshInstallConversionData() {
        logger.log("AppsFlyer conversion refresh requested")
        AppsFlyerLib.shared().start()
    }

    func getLatestAttributionData() -> [AnyHashable: Any] {
        latestAttributionData
    }

    func fetchInstallConversionDataSnapshot() async -> [AnyHashable: Any]? {
        let sdk = AppsFlyerLib.shared()
        let appId = sdk.appleAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        let devKey = sdk.appsFlyerDevKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let deviceId = (sdk.getAppsFlyerUID() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !appId.isEmpty, !devKey.isEmpty, !deviceId.isEmpty else {
            logger.log(
                "AppsFlyer direct install request skipped: missing appId/devKey/deviceId",
                level: .error
            )
            return nil
        }

        var components = URLComponents(string: "https://gcdsdk.appsflyer.com/install_data/v4.0/\(appId)")
        components?.queryItems = [
            URLQueryItem(name: "devkey", value: devKey),
            URLQueryItem(name: "device_id", value: deviceId)
        ]
        guard let url = components?.url else {
            logger.log("AppsFlyer direct install request failed: invalid URL components", level: .error)
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                logger.log("AppsFlyer direct install request failed: HTTP \(http.statusCode)", level: .error)
                return nil
            }
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any] else {
                logger.log("AppsFlyer direct install request failed: response is not a dictionary", level: .error)
                return nil
            }
            logger.log("AppsFlyer direct install request success: \(parsed)")
            return parsed
        } catch {
            logger.log("AppsFlyer direct install request error: \(error.localizedDescription)", level: .error)
            return nil
        }
    }

    // MARK: - AppsFlyerLibDelegate

    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        logger.log("AppsFlyer conversion success: \(conversionInfo)")
        conversionDataSink.updateConversionData(conversionInfo)
        NotificationCenter.default.post(name: .didReceiveConversionData, object: conversionInfo)
    }

    func onConversionDataFail(_ error: Error) {
        logger.log("AppsFlyer conversion fail: \(error.localizedDescription)")
        NotificationCenter.default.post(name: .didFailConversionData, object: error)
    }

    func onAppOpenAttribution(_ attributionData: [AnyHashable: Any]) {
        logger.log("AppsFlyer attribution: \(attributionData)")
        latestAttributionData = attributionData
        NotificationCenter.default.post(name: .didReceiveAttributionData, object: attributionData)
    }

    func onAppOpenAttributionFailure(_ error: Error) {
        logger.log("AppsFlyer attribution fail: \(error.localizedDescription)")
        NotificationCenter.default.post(name: .didFailAttribution, object: error)
    }
}

// MARK: - Notification names

extension Notification.Name {

    /// Posted when conversion data is successfully received.
    static let didReceiveConversionData = Notification.Name("didReceiveConversionData")

    /// Posted when conversion data retrieval fails.
    static let didFailConversionData = Notification.Name("didFailConversionData")

    /// Posted when attribution data is successfully received.
    static let didReceiveAttributionData = Notification.Name("didReceiveAttributionData")

    /// Posted when attribution data retrieval fails.
    static let didFailAttribution = Notification.Name("didFailAttribution")
}
