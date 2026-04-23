import Foundation

/// Use case: run app initialization (config checks, conversion data, server request, state resolution).
/// Conforms to AppInitializerUseCaseProtocol from AppInitialization feature.
final class InitializeAppUseCase: AppInitializerUseCaseProtocol {

    private let configuration: AppConfigurationProtocol
    private let fetchConversionDataUseCase: FetchConversionDataUseCaseProtocol
    private let analyticsRepository: AnalyticsRepositoryProtocol
    private let networkRepository: NetworkRepositoryProtocol
    private let networkConnectivityChecker: NetworkConnectivityCheckingProtocol
    private let fcmTokenDataSource: FCMTokenDataSourceProtocol
    private let startupStateStore: StartupStateStoreProtocol
    private let logger: Logging
    private let atsHostRegistrar: AppTransportSecurityHostRegistrarProtocol
    private let organicRefreshDelayNanoseconds: UInt64
    private let preRequestWaitTimeoutNanoseconds: UInt64
    private let preRequestPollIntervalNanoseconds: UInt64
    private(set) var latestDiagnostics: StartupDiagnostics = .empty

    init(
        configuration: AppConfigurationProtocol,
        fetchConversionDataUseCase: FetchConversionDataUseCaseProtocol,
        analyticsRepository: AnalyticsRepositoryProtocol,
        networkRepository: NetworkRepositoryProtocol,
        networkConnectivityChecker: NetworkConnectivityCheckingProtocol = AssumeNetworkReachableConnectivityChecker(),
        fcmTokenDataSource: FCMTokenDataSourceProtocol,
        startupStateStore: StartupStateStoreProtocol,
        logger: Logging,
        atsHostRegistrar: AppTransportSecurityHostRegistrarProtocol,
        organicRefreshDelay: TimeInterval = 5.0,
        preRequestWaitTimeout: TimeInterval = 15.0,
        preRequestPollInterval: TimeInterval = 0.5
    ) {
        self.configuration = configuration
        self.fetchConversionDataUseCase = fetchConversionDataUseCase
        self.analyticsRepository = analyticsRepository
        self.networkRepository = networkRepository
        self.networkConnectivityChecker = networkConnectivityChecker
        self.fcmTokenDataSource = fcmTokenDataSource
        self.startupStateStore = startupStateStore
        self.logger = logger
        self.atsHostRegistrar = atsHostRegistrar
        self.organicRefreshDelayNanoseconds = max(0, UInt64(organicRefreshDelay * 1_000_000_000))
        self.preRequestWaitTimeoutNanoseconds = max(0, UInt64(preRequestWaitTimeout * 1_000_000_000))
        self.preRequestPollIntervalNanoseconds = max(1_000_000, UInt64(preRequestPollInterval * 1_000_000_000))
    }

    func execute(pushToken: String?, hasLaunchedBefore: Bool) async -> AppState {
        var diagnostics = StartupDiagnostics.empty
        var firebaseSnapshot: [String: Any] = [:]
        var appsFlyerSnapshot: [AnyHashable: Any] = [:]
        var serverRequestSnapshot: [String: Any] = [:]
        var serverResponseSnapshot: [String: Any] = [:]

        func setFirebase(status: StartupDiagnosticStatus, summary: String) {
            diagnostics = StartupDiagnostics(
                firebase: StartupDiagnosticStage(status: status, summary: summary, targetState: nil),
                appsFlyer: diagnostics.appsFlyer,
                serverRequest: diagnostics.serverRequest,
                finalState: diagnostics.finalState,
                more: diagnostics.more
            )
        }

        func setAppsFlyer(status: StartupDiagnosticStatus, summary: String) {
            diagnostics = StartupDiagnostics(
                firebase: diagnostics.firebase,
                appsFlyer: StartupDiagnosticStage(status: status, summary: summary, targetState: nil),
                serverRequest: diagnostics.serverRequest,
                finalState: diagnostics.finalState,
                more: diagnostics.more
            )
        }

        func setServer(status: StartupDiagnosticStatus, summary: String) {
            diagnostics = StartupDiagnostics(
                firebase: diagnostics.firebase,
                appsFlyer: diagnostics.appsFlyer,
                serverRequest: StartupDiagnosticStage(status: status, summary: summary, targetState: nil),
                finalState: diagnostics.finalState,
                more: diagnostics.more
            )
        }

        func setFinal(_ state: AppState, summary: String) {
            diagnostics = StartupDiagnostics(
                firebase: diagnostics.firebase,
                appsFlyer: diagnostics.appsFlyer,
                serverRequest: diagnostics.serverRequest,
                finalState: StartupDiagnosticStage(
                    status: .ok,
                    summary: summary,
                    targetState: shortStateName(state)
                ),
                more: diagnostics.more
            )
        }

        func refreshMoreData() {
            diagnostics = StartupDiagnostics(
                firebase: diagnostics.firebase,
                appsFlyer: diagnostics.appsFlyer,
                serverRequest: diagnostics.serverRequest,
                finalState: diagnostics.finalState,
                more: StartupMoreData(
                    firebaseData: prettyPrintedString(from: firebaseSnapshot),
                    appsFlyerData: prettyPrintedString(from: appsFlyerSnapshot),
                    serverRequestData: prettyPrintedString(from: serverRequestSnapshot),
                    serverResponseData: prettyPrintedString(from: serverResponseSnapshot)
                )
            )
        }

        func finish(_ state: AppState, finalSummary: String) -> AppState {
            setFinal(state, summary: finalSummary)
            refreshMoreData()
            latestDiagnostics = diagnostics
            return state
        }

        let isDebugFlagsEnabled = configuration.isDebug
        let isGameOnlyEnabled = isDebugFlagsEnabled && configuration.isGameOnly
        let isWebOnlyEnabled = isDebugFlagsEnabled && configuration.isWebOnly
        let isNoNetworkEnabled = isDebugFlagsEnabled && configuration.isNoNetwork
        let isInfinityLoadingEnabled = isDebugFlagsEnabled && configuration.isInfinityLoading
        let isAskNotificationsEnabled = configuration.isAskNotifications

        if isAskNotificationsEnabled {
            setFirebase(status: .ok, summary: "Firebase stage skipped (isAskNotifications enabled).")
            setAppsFlyer(status: .ok, summary: "AppsFlyer stage skipped (isAskNotifications enabled).")
            setServer(status: .ok, summary: "Server request was not sent (isAskNotifications enabled).")
            firebaseSnapshot = ["status": "skipped", "reason": "isAskNotifications=true"]
            appsFlyerSnapshot = ["status": "skipped", "reason": "isAskNotifications=true"]
            serverRequestSnapshot = ["status": "skipped", "reason": "isAskNotifications=true"]
            serverResponseSnapshot = ["status": "skipped", "reason": "isAskNotifications=true"]
            let askURL = resolveWebOnlyFallbackURL()
            return finish(.askNotifications(askURL), finalSummary: "Startup ended in askNotifications state.")
        }

        if isGameOnlyEnabled {
            setFirebase(status: .ok, summary: "Firebase stage skipped (isGameOnly enabled).")
            setAppsFlyer(status: .ok, summary: "AppsFlyer data was not requested (isGameOnly enabled).")
            setServer(status: .ok, summary: "Server request was not sent (isGameOnly enabled).")
            firebaseSnapshot = ["status": "skipped", "reason": "isGameOnly=true"]
            appsFlyerSnapshot = ["status": "skipped", "reason": "isGameOnly=true"]
            serverResponseSnapshot = ["status": "skipped", "reason": "isGameOnly=true"]
            return finish(.native, finalSummary: "Startup ended in native shell state.")
        }

        let isNetworkReachable = await networkConnectivityChecker.isNetworkReachable()
        if !isNetworkReachable {
            setFirebase(status: .fail, summary: "Startup halted before config check because network path is unsatisfied.")
            setAppsFlyer(status: .fail, summary: "AppsFlyer data was not requested because device is offline.")
            setServer(status: .fail, summary: "Server request was not sent because device is offline.")
            firebaseSnapshot = [
                "status": "offline",
                "reason": "network path unsatisfied on startup"
            ]
            appsFlyerSnapshot = [
                "status": "skipped",
                "reason": "offline before conversion request"
            ]
            serverResponseSnapshot = [
                "status": "skipped",
                "reason": "offline before config request"
            ]
            return finish(.noInternet, finalSummary: "Startup ended in noInternet state (offline before config check).")
        }

        if isInfinityLoadingEnabled {
            setFirebase(status: .ok, summary: "Firebase stage skipped (isInfinityLoading enabled).")
            setAppsFlyer(status: .ok, summary: "AppsFlyer data was not requested (isInfinityLoading enabled).")
            setServer(status: .ok, summary: "Server request was not sent (isInfinityLoading enabled).")
            firebaseSnapshot = ["status": "skipped", "reason": "isInfinityLoading=true"]
            serverResponseSnapshot = ["status": "skipped", "reason": "isInfinityLoading=true"]
            return finish(.loading, finalSummary: "Startup ended in loading state.")
        }

        if isNoNetworkEnabled {
            setFirebase(status: .ok, summary: "Firebase stage completed.")
            setAppsFlyer(status: .ok, summary: "AppsFlyer data was not requested (isNoNetwork enabled).")
            setServer(status: .fail, summary: "Server request was not sent (isNoNetwork enabled).")
            firebaseSnapshot = ["status": "ready", "reason": "network disabled before request"]
            serverResponseSnapshot = ["status": "skipped", "reason": "isNoNetwork=true"]
            if startupStateStore.mode == .native {
                return finish(.native, finalSummary: "Startup ended in native shell state (persisted mode).")
            }
            return finish(.noInternet, finalSummary: "Startup ended in noInternet state.")
        }

        if startupStateStore.isConfigRequestsDisabled {
            setFirebase(status: .ok, summary: "Firebase stage completed.")
            setAppsFlyer(status: .ok, summary: "AppsFlyer data was not requested (config requests disabled).")
            setServer(status: .ok, summary: "Server request was not sent (config requests disabled).")
            firebaseSnapshot = ["status": "ready", "reason": "config requests disabled"]
            serverResponseSnapshot = ["status": "skipped", "reason": "config requests disabled"]
            startupStateStore.mode = .native
            return finish(.native, finalSummary: "Startup ended in native shell state.")
        }

        var conversionData = await fetchConversionDataUseCase.execute()
        let attributionData = analyticsRepository.getLatestAttributionData()
        conversionData = mergedAttributionPayload(
            conversionData: conversionData,
            attributionData: attributionData
        )
        let initialConversionData = conversionData
        appsFlyerSnapshot = conversionData
        setAppsFlyer(
            status: conversionData.isEmpty ? .fail : .ok,
            summary: conversionData.isEmpty
                ? "AppsFlyer data not received."
                : "AppsFlyer data received."
        )

        let shouldRetryAppsFlyerFetch =
            conversionData.isEmpty ||
            (!hasLaunchedBefore && isOrganicStatus(appsFlyerStatus(from: conversionData)))

        if shouldRetryAppsFlyerFetch {
            if conversionData.isEmpty {
                logger.log("InitializeAppUseCase: AppsFlyer data is empty, requesting delayed refresh")
            } else {
                logger.log("InitializeAppUseCase: organic conversion on first launch, requesting refresh")
            }
            analyticsRepository.refreshInstallConversionData()
            if organicRefreshDelayNanoseconds > 0 {
                logger.log("InitializeAppUseCase: waiting \(organicRefreshDelayNanoseconds / 1_000_000_000)s before conversion refresh fetch")
                try? await Task.sleep(nanoseconds: organicRefreshDelayNanoseconds)
            }
            let refreshedConversionData = await fetchConversionDataUseCase.execute()
            let directInstallSnapshot = await analyticsRepository.fetchInstallConversionDataSnapshot()
            let enrichedRefreshedData = enrichConversionData(
                refreshedConversionData,
                withDirectInstallSnapshot: directInstallSnapshot
            )
            let mergedRefreshedData = mergedAttributionPayload(
                conversionData: enrichedRefreshedData,
                attributionData: attributionData
            )
            if !mergedRefreshedData.isEmpty {
                conversionData = mergedRefreshedData
                logger.log(
                    "InitializeAppUseCase: conversion data refreshed, af_status=\(appsFlyerStatus(from: mergedRefreshedData) ?? "nil")"
                )
                appsFlyerSnapshot = [
                    "initial_fetch": normalizeDictionary(initialConversionData),
                    "retry_fetch": normalizeDictionary(mergedRefreshedData),
                    "effective_payload": normalizeDictionary(conversionData)
                ]
                let summary = conversionData.isEmpty
                    ? "AppsFlyer data not received."
                    : "AppsFlyer data received after delayed retry."
                setAppsFlyer(status: .ok, summary: summary)
            } else {
                logger.log("InitializeAppUseCase: conversion refresh returned empty payload")
                appsFlyerSnapshot = [
                    "initial_fetch": normalizeDictionary(initialConversionData),
                    "retry_fetch": [
                        "status": "empty"
                    ],
                    "effective_payload": normalizeDictionary(conversionData)
                ]
                if conversionData.isEmpty {
                    setAppsFlyer(status: .fail, summary: "AppsFlyer data not received after delayed retry.")
                } else {
                    setAppsFlyer(status: .ok, summary: "AppsFlyer data received.")
                }
            }
        }

        var afId = analyticsRepository.getAnalyticsUserId() ?? ""
        var pushTokenValue = resolvePushToken(initialPushToken: pushToken)
        if shouldWaitForRequestData(afId: afId, pushToken: pushTokenValue, conversionData: conversionData) {
            logger.log("InitializeAppUseCase: waiting for Firebase and AppsFlyer data before server request")
            let ready = await waitForRequestData(
                currentConversionData: &conversionData,
                currentAfId: &afId,
                currentPushToken: &pushTokenValue
            )
            if !ready {
                logger.log(
                    "InitializeAppUseCase: timed out waiting for full Firebase/AppsFlyer data, request will continue with latest snapshot",
                    level: .error
                )
            }
        }

        let hasPushToken = !pushTokenValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAfId = !afId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let pushTokenFailureReason = resolvePushTokenFailureReason(pushToken: pushTokenValue)
        let apnsStatus = fcmTokenDataSource.apnsStatus
        let apnsError = fcmTokenDataSource.apnsErrorDescription
        let isRegisteredForRemoteNotifications = fcmTokenDataSource.isRegisteredForRemoteNotifications
        let notificationAuthorizationStatus = fcmTokenDataSource.notificationAuthorizationStatus
        var payload = buildPayload(
            conversionData: conversionData,
            afId: afId,
            pushToken: pushTokenValue
        )
        if isWebOnlyEnabled {
            payload["af_status"] = "Non-organic"
        }
        serverRequestSnapshot = payload
        let hasPairInPayload =
            !(payload["push_token"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !(payload["af_id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let firebaseStatus: StartupDiagnosticStatus = hasPairInPayload ? .ok : .fail
        let firebaseSummary = """
        firebaseToken: \(hasPushToken ? "received" : "missing"), \
        firebaseTokenReason: \(pushTokenFailureReason), \
        apnsStatus: \(apnsStatus), \
        apnsError: \(apnsError ?? "none"), \
        isRegisteredForRemoteNotifications: \(isRegisteredForRemoteNotifications), \
        notificationAuthorizationStatus: \(notificationAuthorizationStatus), \
        af_id: \(hasAfId ? "received" : "missing"), \
        pair sent to server: \(hasPairInPayload ? "yes" : "no")
        """
        setFirebase(status: firebaseStatus, summary: firebaseSummary)
        firebaseSnapshot = [
            "firebase_token": hasPushToken ? pushTokenValue : NSNull(),
            "firebase_token_reason": pushTokenFailureReason,
            "apns_status": apnsStatus,
            "apns_error": apnsError ?? NSNull(),
            "is_registered_for_remote_notifications": isRegisteredForRemoteNotifications,
            "notification_authorization_status": notificationAuthorizationStatus,
            "af_id": hasAfId ? afId : NSNull(),
            "pair_ready_for_server": hasPairInPayload
        ]

        if isWebOnlyEnabled {
            do {
                let configResult = try await networkRepository.fetchConfig(
                    usingPayload: payload as [AnyHashable: Any],
                    timeout: 30.0
                )
                let urlString = configResult.urlString
                let urlFromServer = urlString.flatMap { URL(string: $0) }
                logger.log(
                    "InitializeAppUseCase: webOnly mode, server urlString=\(urlString ?? "nil"), parsedURL=\(urlFromServer?.absoluteString ?? "nil")"
                )
                setServer(status: .ok, summary: "Server request sent successfully.")
                serverResponseSnapshot = [
                    "ok": urlString != nil,
                    "mode": "webOnly",
                    "url": urlString ?? NSNull(),
                    "parsed_url": urlFromServer?.absoluteString ?? NSNull()
                ]
                await registerConfigHosts(webURL: urlFromServer, expiresAt: configResult.expiresAt)
                if let url = urlFromServer {
                    startupStateStore.mode = .web
                    if hasLaunchedBefore {
                        updateCachedWebConfigIfNeeded(
                            newURL: url,
                            expiresAt: configResult.expiresAt
                        )
                    } else {
                        startupStateStore.cachedWebConfig = CachedWebConfig(
                            urlString: url.absoluteString,
                            expiresAt: configResult.expiresAt
                        )
                    }
                    logger.log("InitializeAppUseCase: app state -> web (webOnly server URL)")
                    return finish(.web(url), finalSummary: "Final state resolved.")
                }
            } catch {
                logger.log(
                    "InitializeAppUseCase: webOnly request failed: \(error.localizedDescription)",
                    level: .error
                )
                if let fallbackURL = resolvedCachedWebURL() {
                    await registerConfigHosts(
                        webURL: fallbackURL,
                        expiresAt: startupStateStore.cachedWebConfig?.expiresAt
                    )
                    logger.log("InitializeAppUseCase: app state -> web (webOnly cached fallback)")
                    return finish(.web(fallbackURL), finalSummary: "Final state resolved.")
                } else {
                    setServer(status: .fail, summary: "Server request failed.")
                    serverResponseSnapshot = [
                        "ok": false,
                        "mode": "webOnly",
                        "url": NSNull(),
                        "error": error.localizedDescription
                    ]
                }
            }
            startupStateStore.mode = .web
            return finish(.web(resolveWebOnlyFallbackURL()), finalSummary: "Final state resolved.")
        }

        do {
            let configResult = try await networkRepository.fetchConfig(
                usingPayload: payload as [AnyHashable: Any],
                timeout: 30.0
            )
            let urlString = configResult.urlString
            let urlFromServer = urlString.flatMap { URL(string: $0) }
            logger.log(
                "InitializeAppUseCase: server urlString=\(urlString ?? "nil"), parsedURL=\(urlFromServer?.absoluteString ?? "nil")"
            )
            setServer(status: .ok, summary: "Server request sent successfully.")
            serverResponseSnapshot = [
                "ok": urlString != nil,
                "url": urlString ?? NSNull(),
                "parsed_url": urlFromServer?.absoluteString ?? NSNull()
            ]
            if urlString != nil && urlFromServer == nil {
                logger.log("InitializeAppUseCase: server URL string is invalid for URL initialization", level: .error)
            }
            await registerConfigHosts(webURL: urlFromServer, expiresAt: configResult.expiresAt)

            let shouldShowAskNotificationsRepeat = AskNotificationsRepeatState.shouldShowRepeat()
            if shouldShowAskNotificationsRepeat {
                if let url = urlFromServer {
                    logger.log("InitializeAppUseCase: app state -> askNotifications (repeat)")
                    return finish(.askNotifications(url), finalSummary: "Final state resolved.")
                }
                logger.log(
                    "InitializeAppUseCase: repeat askNotifications due but URL is unavailable, keeping pending repeat",
                    level: .error
                )
            }

            if !hasLaunchedBefore {
                if let url = urlFromServer {
                    startupStateStore.mode = .web
                    startupStateStore.cachedWebConfig = CachedWebConfig(
                        urlString: url.absoluteString,
                        expiresAt: configResult.expiresAt
                    )
                    logger.log("InitializeAppUseCase: app state -> firstLaunch")
                    return finish(.firstLaunch(url), finalSummary: "Final state resolved.")
                } else {
                    startupStateStore.mode = .native
                    startupStateStore.isConfigRequestsDisabled = true
                    logger.log("InitializeAppUseCase: app state -> native (first launch without URL)")
                    return finish(.native, finalSummary: "Final state resolved.")
                }
            }
            if let url = urlFromServer {
                startupStateStore.mode = .web
                if hasLaunchedBefore {
                    updateCachedWebConfigIfNeeded(
                        newURL: url,
                        expiresAt: configResult.expiresAt
                    )
                } else {
                    startupStateStore.cachedWebConfig = CachedWebConfig(
                        urlString: url.absoluteString,
                        expiresAt: configResult.expiresAt
                    )
                }
                logger.log("InitializeAppUseCase: app state -> web")
                return finish(.web(url), finalSummary: "Final state resolved.")
            }
            startupStateStore.mode = .native
            startupStateStore.isConfigRequestsDisabled = true
            logger.log("InitializeAppUseCase: app state -> native (no URL from server)")
            return finish(.native, finalSummary: "Final state resolved.")
        } catch {
            logger.log("InitializeAppUseCase network request failed: \(error.localizedDescription)", level: .error)
            setServer(status: .fail, summary: "Server request failed.")
            serverResponseSnapshot = [
                "ok": false,
                "url": NSNull(),
                "error": error.localizedDescription
            ]
            if let fallbackURL = resolvedCachedWebURL() {
                startupStateStore.mode = .web
                await registerConfigHosts(
                    webURL: fallbackURL,
                    expiresAt: startupStateStore.cachedWebConfig?.expiresAt
                )
                logger.log("InitializeAppUseCase: app state -> web (cached URL fallback)")
                return finish(.web(fallbackURL), finalSummary: "Final state resolved.")
            }
            startupStateStore.mode = .native
            return finish(.native, finalSummary: "Final state resolved.")
        }
    }

    private func registerConfigHosts(webURL: URL?, expiresAt: Date?) async {
        let trimmed = configuration.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let configRequestURL = trimmed.isEmpty ? nil : URL(string: trimmed)
        await atsHostRegistrar.registerHostsFromConfigResponse(
            webURL: webURL,
            configRequestURL: configRequestURL,
            expiresAt: expiresAt
        )
    }

    private func buildPayload(
        conversionData: [AnyHashable: Any],
        afId: String,
        pushToken: String
    ) -> [String: Any] {
        // Copy all key/value pairs from conversion data (string keys only) to support arbitrary payload keys.
        var payload: [String: Any] = [:]
        for (key, value) in conversionData {
            if let stringKey = key as? String {
                payload[stringKey] = value
            }
        }

        // Inject/override known technical keys so they always reflect current config and params.
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown.bundle"
        let locale = Locale.current.identifier
        payload["af_id"] = afId
        payload["bundle_id"] = bundleId
        payload["os"] = configuration.os
        payload["store_id"] = configuration.storeIdWithPrefix
        payload["locale"] = locale
        payload["firebase_project_id"] = configuration.firebaseProjectId
        payload["push_token"] = pushToken
        payload["firebase_token"] = pushToken
        if payload["af_status"] == nil {
            payload["af_status"] = "Organic"
        }

        return payload
    }

    private func appsFlyerStatus(from conversionData: [AnyHashable: Any]) -> String? {
        conversionData["af_status"] as? String
    }

    private func isOrganicStatus(_ status: String?) -> Bool {
        guard let status else { return false }
        let normalizedStatus = status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        return normalizedStatus == "organic"
    }

    private func resolvePushToken(initialPushToken: String?) -> String {
        let initial = (initialPushToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !initial.isEmpty {
            return initial
        }
        let latest = (fcmTokenDataSource.token ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return latest
    }

    private func shouldWaitForRequestData(
        afId: String,
        pushToken: String,
        conversionData: [AnyHashable: Any]
    ) -> Bool {
        let hasAfId = !afId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPushToken = !pushToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasConversionData = !conversionData.isEmpty
        return !(hasAfId && hasPushToken && hasConversionData)
    }

    private func waitForRequestData(
        currentConversionData: inout [AnyHashable: Any],
        currentAfId: inout String,
        currentPushToken: inout String
    ) async -> Bool {
        let start = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - start < preRequestWaitTimeoutNanoseconds {
            if !currentConversionData.isEmpty,
               !currentAfId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !currentPushToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            if currentConversionData.isEmpty {
                currentConversionData = await fetchConversionDataUseCase.execute()
            }
            if currentAfId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentAfId = analyticsRepository.getAnalyticsUserId() ?? ""
            }
            if currentPushToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentPushToken = resolvePushToken(initialPushToken: nil)
            }
            try? await Task.sleep(nanoseconds: preRequestPollIntervalNanoseconds)
        }
        return !currentConversionData.isEmpty &&
            !currentAfId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !currentPushToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func prettyPrintedString(from dictionary: [AnyHashable: Any]) -> String {
        var normalized: [String: Any] = [:]
        for (key, value) in dictionary {
            if let stringKey = key as? String {
                normalized[stringKey] = value
            }
        }
        return prettyPrintedString(from: normalized)
    }

    private func prettyPrintedString(from dictionary: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(dictionary),
              let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8)
        else {
            return String(describing: dictionary)
        }
        return json
    }

    private func normalizeDictionary(_ dictionary: [AnyHashable: Any]) -> [String: Any] {
        var normalized: [String: Any] = [:]
        for (key, value) in dictionary {
            if let stringKey = key as? String {
                normalized[stringKey] = value
            }
        }
        return normalized
    }

    private func shortStateName(_ state: AppState) -> String {
        switch state {
        case .loading:
            return ".loading"
        case .native:
            return ".native"
        case .web:
            return ".web"
        case .firstLaunch:
            return ".firstLaunch"
        case .askNotifications:
            return ".askNotifications"
        case .error:
            return ".error"
        case .noInternet:
            return ".noInternet"
        case .testState(_):
            return ".testState"
        }
    }

    private func mergedAttributionPayload(
        conversionData: [AnyHashable: Any],
        attributionData: [AnyHashable: Any]
    ) -> [AnyHashable: Any] {
        var merged = conversionData
        for (key, value) in attributionData {
            guard merged[key] == nil else {
                // Special-case: ensure attribution can override installation organic status.
                // This happens when AppsFlyer sends an initial organic conversion callback,
                // then later provides non-organic attribution info (e.g. UDL/deep link).
                if let stringKey = key as? String, stringKey == "af_status" {
                    let conversionStatus = merged[key] as? String
                    let attributionStatus = value as? String
                    if shouldOverrideAfStatus(conversionStatus: conversionStatus, attributionStatus: attributionStatus) {
                        merged[key] = value
                    }
                }
                continue
            }
            merged[key] = value
        }
        return merged
    }

    private func enrichConversionData(
        _ conversionData: [AnyHashable: Any],
        withDirectInstallSnapshot snapshot: [AnyHashable: Any]?
    ) -> [AnyHashable: Any] {
        guard let snapshot, !snapshot.isEmpty else { return conversionData }
        var merged = conversionData
        for (key, value) in snapshot {
            if merged[key] == nil {
                merged[key] = value
                continue
            }
            if let stringKey = key as? String, stringKey == "af_status" {
                let conversionStatus = merged[key] as? String
                let snapshotStatus = value as? String
                if shouldOverrideAfStatus(conversionStatus: conversionStatus, attributionStatus: snapshotStatus) {
                    merged[key] = value
                }
            }
        }
        return merged
    }

    private func shouldOverrideAfStatus(conversionStatus: String?, attributionStatus: String?) -> Bool {
        guard let attributionStatus else { return false }
        // Only override when we have an explicit non-organic attribution.
        // Never downgrade: if conversion already says non-organic, keep it.
        if isOrganicStatus(conversionStatus) == true && isOrganicStatus(attributionStatus) == false {
            return true
        }
        return false
    }

    private func resolvedCachedWebURL() -> URL? {
        guard let cachedWebConfig = startupStateStore.cachedWebConfig,
              let cachedURL = URL(string: cachedWebConfig.urlString) else {
            return nil
        }
        return cachedURL
    }

    private func updateCachedWebConfigIfNeeded(newURL: URL, expiresAt: Date?) {
        let normalizedNewURL = newURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedNewURL.isEmpty else { return }

        if let cachedWebConfig = startupStateStore.cachedWebConfig {
            let normalizedCachedURL = cachedWebConfig.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedCachedURL == normalizedNewURL {
                startupStateStore.cachedWebConfig = CachedWebConfig(
                    urlString: normalizedNewURL,
                    expiresAt: expiresAt
                )
                logger.log("InitializeAppUseCase: cached web URL is unchanged on repeat launch")
                return
            }
            logger.log(
                "InitializeAppUseCase: cached web URL changed on repeat launch, updating cache from \(normalizedCachedURL) to \(normalizedNewURL)"
            )
        } else {
            logger.log("InitializeAppUseCase: cached web URL missing on repeat launch, storing new URL")
        }

        startupStateStore.cachedWebConfig = CachedWebConfig(
            urlString: normalizedNewURL,
            expiresAt: expiresAt
        )
    }

    private func resolvePushTokenFailureReason(pushToken: String) -> String {
        let normalizedToken = pushToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedToken.isEmpty {
            return "token is present"
        }

        let cachedToken = (fcmTokenDataSource.token ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cachedToken.isEmpty {
            return "token exists in local store but was not provided to startup"
        }

        if fcmTokenDataSource.apnsStatus == "failed" {
            let apnsError = fcmTokenDataSource.apnsErrorDescription ?? "unknown APNS registration error"
            return "APNS registration failed: \(apnsError)"
        }
        if fcmTokenDataSource.apnsStatus == "pending" {
            return "APNS registration is still pending, Firebase token request may still be in progress"
        }

        return "FCM token is unavailable (APNS registration may have failed, Firebase token request may still be pending, or network is unavailable)"
    }

    private func resolveWebOnlyFallbackURL() -> URL {
        if let cachedURL = resolvedCachedWebURL() {
            return cachedURL
        }
        if let configURL = URL(string: configuration.serverURL) {
            return configURL
        }
        return URL(string: "about:blank")!
    }

}
