import Foundation

/// Protocol for the application dependency container. Provides access to configuration,
/// repositories, use cases, logging, and local data sources. Use this protocol in views/view models for testability.
/// Tests can substitute the container via `AppDependencies.containerForTesting` set before app launch.
protocol DependencyContainer: AnyObject {
    var configuration: AppConfigurationProtocol { get }
    var analyticsRepository: AnalyticsRepositoryProtocol { get }
    var networkRepository: NetworkRepositoryProtocol { get }
    var networkConnectivityChecker: NetworkConnectivityCheckingProtocol { get }
    var conversionDataRepository: ConversionDataRepositoryProtocol { get }
    var fcmTokenDataSource: FCMTokenDataSourceProtocol { get }
    var startupStateStore: StartupStateStoreProtocol { get }
    var initializeAppUseCase: AppInitializerUseCaseProtocol { get }
    var pushTokenProvider: PushTokenProviderProtocol { get }
    var timerSessionStore: TimerSessionStoreProtocol { get }
    var logger: Logging { get }
    var logStorage: LogStorageProtocol { get }
}

/// Default implementation of the dependency container. Holds references to injected dependencies.
final class DefaultDependencyContainer: DependencyContainer {

    private(set) var configuration: AppConfigurationProtocol
    private(set) var analyticsRepository: AnalyticsRepositoryProtocol
    private(set) var networkRepository: NetworkRepositoryProtocol
    private(set) var networkConnectivityChecker: NetworkConnectivityCheckingProtocol
    private(set) var conversionDataRepository: ConversionDataRepositoryProtocol
    private(set) var fcmTokenDataSource: FCMTokenDataSourceProtocol
    private(set) var startupStateStore: StartupStateStoreProtocol
    private(set) var initializeAppUseCase: AppInitializerUseCaseProtocol
    private(set) var pushTokenProvider: PushTokenProviderProtocol
    private(set) var timerSessionStore: TimerSessionStoreProtocol
    private(set) var logger: Logging
    private(set) var logStorage: LogStorageProtocol

    /// Creates a container with the given dependencies.
    init(
        configuration: AppConfigurationProtocol,
        analyticsRepository: AnalyticsRepositoryProtocol,
        networkRepository: NetworkRepositoryProtocol,
        networkConnectivityChecker: NetworkConnectivityCheckingProtocol,
        conversionDataRepository: ConversionDataRepositoryProtocol,
        fcmTokenDataSource: FCMTokenDataSourceProtocol,
        startupStateStore: StartupStateStoreProtocol,
        initializeAppUseCase: AppInitializerUseCaseProtocol,
        pushTokenProvider: PushTokenProviderProtocol,
        timerSessionStore: TimerSessionStoreProtocol,
        logger: Logging,
        logStorage: LogStorageProtocol
    ) {
        self.configuration = configuration
        self.analyticsRepository = analyticsRepository
        self.networkRepository = networkRepository
        self.networkConnectivityChecker = networkConnectivityChecker
        self.conversionDataRepository = conversionDataRepository
        self.fcmTokenDataSource = fcmTokenDataSource
        self.startupStateStore = startupStateStore
        self.initializeAppUseCase = initializeAppUseCase
        self.pushTokenProvider = pushTokenProvider
        self.timerSessionStore = timerSessionStore
        self.logger = logger
        self.logStorage = logStorage
    }
}
