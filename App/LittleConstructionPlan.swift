import SwiftUI
import Combine
import UIKit

/// Holds the app view model built from the launch container. Created once when LittleConstructionPlan initializes.
@MainActor
private final class AppViewModelHolder: ObservableObject {
    let container: DependencyContainer
    lazy var viewModel: AppViewModel = AppViewModel(
        initializeAppUseCase: container.initializeAppUseCase,
        pushTokenProvider: container.pushTokenProvider,
        networkConnectivityChecker: container.networkConnectivityChecker,
        configuration: container.configuration
    )
    init(container: DependencyContainer) {
        self.container = container
    }
}

/// Main application entry point. AppDelegate creates the dependency container at launch and assigns it
/// so LittleConstructionPlan can read it once to build the view model and inject into the hierarchy. No global singleton.
@main
@MainActor
struct LittleConstructionPlan: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var holder: AppViewModelHolder
    @StateObject private var deepLinkRouter = DeepLinkRouter()

    init() {
        // Container is set in AppDelegate.didFinishLaunching, which runs before SwiftUI creates the App.
        _holder = StateObject(wrappedValue: AppViewModelHolder(container: AppDependencies.launchContainer!))
    }

    var body: some Scene {
        let container = appDelegate.container
        return WindowGroup {
            RootView()
                .environment(\.dependencyContainer, container)
                .environmentObject(holder.viewModel)
                .onAppear {
                    appDelegate.deepLinkRouter = deepLinkRouter
                    appDelegate.flushBufferedNotificationDeepLinks(using: deepLinkRouter)
                    Task { @MainActor in
                        if let startupNotificationURL = await appDelegate.consumeStartupNotificationDeepLinkURLIfAvailable() {
                            holder.viewModel.openDeepLinkPrioritizingStartup(url: startupNotificationURL)
                        } else {
                            holder.viewModel.start()
                        }
                    }
                    appDelegate.triggerTrackingAuthorizationFlowIfNeeded()
                    appDelegate.updateOrientationLock(orientationLock(for: holder.viewModel.state))
                }
                .onChange(of: scenePhase) { newPhase in
                    guard newPhase == .active else { return }
                    appDelegate.triggerTrackingAuthorizationFlowIfNeeded()
                    appDelegate.updateOrientationLock(orientationLock(for: holder.viewModel.state))
                }
                .onOpenURL { url in
                    let resolution = deepLinkRouter.handleIncomingURL(url)
                    if case .resolved(let resolvedURL) = resolution {
                        appDelegate.container?.logger.log(
                            "DeepLink resolved in onOpenURL to web: \(resolvedURL.absoluteString)"
                        )
                    }
                    if case .rejected(let reason) = resolution {
                        appDelegate.container?.logger.log(
                            "DeepLink rejected in onOpenURL: \(reason)",
                            level: .error
                        )
                    }
                }
                .onReceive(deepLinkRouter.$pendingURL.compactMap { $0 }) { url in
                    holder.viewModel.openDeepLink(url: url)
                    deepLinkRouter.clearPendingURL()
                }
        }
    }

    private func orientationLock(for state: AppState) -> UIInterfaceOrientationMask {
        switch state {
        case .native:
            return .portrait
        default:
            return .allButUpsideDown
        }
    }
}
