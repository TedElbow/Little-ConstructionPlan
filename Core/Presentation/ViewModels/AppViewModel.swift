import Foundation
import Combine
import SwiftUI

private let hasLaunchedBeforeKey = "HasLaunchedBefore"
private let loadingDiagnosticsTimeoutNanoseconds: UInt64 = 10_000_000_000

/// Coordinates application startup flow by delegating to app initializer use case.
/// Depends only on Domain protocols (AppInitializerUseCaseProtocol, PushTokenProviderProtocol).
@MainActor
final class AppViewModel: ObservableObject {
    private let initializeAppUseCase: AppInitializerUseCaseProtocol
    private let pushTokenProvider: PushTokenProviderProtocol
    private let networkConnectivityChecker: NetworkConnectivityCheckingProtocol
    private let configuration: AppConfigurationProtocol
    private var loadingRetryTask: Task<Void, Never>?
    private var loadingStartedAt: UInt64?
    /// Deep link received while startup is still in `.loading`; applied after init resolves.
    private var pendingDeepLinkURL: URL?
    /// Prevents a startup rerun from overriding a just-applied deep link.
    private var shouldSkipNextStart = false

    init(
        initializeAppUseCase: AppInitializerUseCaseProtocol,
        pushTokenProvider: PushTokenProviderProtocol,
        networkConnectivityChecker: NetworkConnectivityCheckingProtocol,
        configuration: AppConfigurationProtocol
    ) {
        self.initializeAppUseCase = initializeAppUseCase
        self.pushTokenProvider = pushTokenProvider
        self.networkConnectivityChecker = networkConnectivityChecker
        self.configuration = configuration
    }

    /// Current application state used to drive UI navigation.
    @Published var state: AppState = .loading

    /// Starts the application initialization flow and updates state from the use case result.
    func start() {
        Task { @MainActor in
            if shouldSkipNextStart {
                shouldSkipNextStart = false
                return
            }
            if state != .loading {
                loadingStartedAt = DispatchTime.now().uptimeNanoseconds
            } else if loadingStartedAt == nil {
                loadingStartedAt = DispatchTime.now().uptimeNanoseconds
            }
            state = .loading
            try? await Task.sleep(nanoseconds: 150_000_000)

            let pushToken = await pushTokenProvider.getToken()
            let hasLaunchedBefore = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)

            let newState = await initializeAppUseCase.execute(
                pushToken: pushToken,
                hasLaunchedBefore: hasLaunchedBefore
            )

            if !hasLaunchedBefore && shouldMarkLaunchAsCompleted(for: newState) {
                UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
            }

            let mappedState = mapStateForDiagnosticsIfNeeded(
                resolvedState: newState,
                diagnostics: initializeAppUseCase.latestDiagnostics
            )
            state = mappedState
            await applyPendingDeepLinkIfNeeded()

            if state == .loading {
                scheduleRetryIfNeeded()
            } else {
                loadingRetryTask?.cancel()
                loadingRetryTask = nil
                loadingStartedAt = nil
            }
        }
    }

    /// Applies a deep link captured during `.loading` so it is not overwritten by startup state.
    private func applyPendingDeepLinkIfNeeded() async {
        guard let url = pendingDeepLinkURL else { return }
        let isReachable = await networkConnectivityChecker.isNetworkReachable()
        if !isReachable {
            pendingDeepLinkURL = nil
            state = .noInternet
            return
        }
        switch state {
        case .web:
            pendingDeepLinkURL = nil
            state = .web(url)
        case .firstLaunch:
            pendingDeepLinkURL = nil
            state = .firstLaunch(url)
        case .askNotifications:
            pendingDeepLinkURL = nil
            state = .askNotifications(url)
        case .native, .error, .loading:
            pendingDeepLinkURL = nil
            state = .web(url)
        case .noInternet:
            // Keep explicit noInternet result from startup and do not override it with deep link.
            pendingDeepLinkURL = nil
        case .testState:
            pendingDeepLinkURL = nil
        }
    }

    private func mapStateForDiagnosticsIfNeeded(resolvedState: AppState, diagnostics: StartupDiagnostics) -> AppState {
        if resolvedState == .loading {
            if configuration.isInfinityLoading {
                return .loading
            }
            if shouldForceDiagnosticsAfterLoadingTimeout() {
                return .testState(diagnostics)
            }
            return .loading
        }
        if configuration.isDebug && configuration.isForceOpenTestState {
            return .testState(diagnostics)
        }
        return resolvedState
    }

    private func shouldMarkLaunchAsCompleted(for state: AppState) -> Bool {
        switch state {
        case .firstLaunch, .web, .native, .askNotifications:
            return true
        case .loading, .error, .noInternet, .testState:
            return false
        }
    }

    /// Opens web content from a resolved deep link.
    func openDeepLink(url: URL) {
        shouldSkipNextStart = true
        if state == .loading {
            pendingDeepLinkURL = nil
            state = .web(url)
            return
        }
        state = .web(url)
    }

    /// Opens a deep link immediately and bypasses startup flow.
    /// Used when launch priority belongs to push notification deep links.
    func openDeepLinkPrioritizingStartup(url: URL) {
        shouldSkipNextStart = true
        pendingDeepLinkURL = nil
        loadingRetryTask?.cancel()
        loadingRetryTask = nil
        loadingStartedAt = nil
        state = .web(url)
    }

    private func scheduleRetryIfNeeded() {
        guard loadingRetryTask == nil else { return }
        loadingRetryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            loadingRetryTask = nil
            start()
        }
    }

    private func shouldForceDiagnosticsAfterLoadingTimeout() -> Bool {
        guard let loadingStartedAt else { return false }
        let elapsed = DispatchTime.now().uptimeNanoseconds - loadingStartedAt
        return elapsed >= loadingDiagnosticsTimeoutNanoseconds
    }
}
