import UIKit
import AppsFlyerLib
import AppTrackingTransparency
import FirebaseCore
import FirebaseMessaging
import UserNotifications

/// Application delegate responsible for configuring Firebase, AppsFlyer,
/// push notifications, and handling application lifecycle events.
/// Holds the dependency container created at launch; LittleConstructionPlan reads it and passes into the view hierarchy.
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    /// Current orientation lock used to restrict supported interface orientations.
    var orientationLock: UIInterfaceOrientationMask = .portrait

    /// Dependency container created at launch. Set in didFinishLaunching; LittleConstructionPlan reads it and injects into views.
    private(set) var container: DependencyContainer!
    weak var deepLinkRouter: DeepLinkRouter?
    private var hasStartedAppsFlyer = false

    /// Push deep links received before `deepLinkRouter` is assigned from SwiftUI `onAppear`.
    private var bufferedNotificationIncomingURLs: [URL] = []

    /// Performs application startup configuration including Firebase setup,
    /// push notification registration, and AppsFlyer initialization.
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        container = AppDependencies.containerForTesting ?? AppDependencies.makeDefaultContainer()
        AppDependencies.setLaunchContainer(container)

        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().delegate = self
        refreshNotificationAuthorizationStatus()
        application.registerForRemoteNotifications()
        container?.fcmTokenDataSource.isRegisteredForRemoteNotifications = application.isRegisteredForRemoteNotifications

        guard let container = self.container else { return true }
        let appsFlyer = AppsFlyerLib.shared()
        appsFlyer.appsFlyerDevKey = container.configuration.appsFlyerDevKey
        appsFlyer.appleAppID = container.configuration.storeIdWithPrefix
        appsFlyer.delegate = container.analyticsRepository as? AppsFlyerLibDelegate
        appsFlyer.isDebug = container.configuration.isDebug
        logRuntimeConfiguration(container: container)

        if let remote = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
            Task { @MainActor in
                self.routeNotificationDeepLinkIfPossible(from: remote, reason: "launchOptions.remoteNotification")
            }
        }

        return true
    }

    /// Delivers buffered push URLs after `DeepLinkRouter` is wired (see `LittleConstructionPlan` `onAppear`).
    @MainActor
    func flushBufferedNotificationDeepLinks(using router: DeepLinkRouter) {
        guard !bufferedNotificationIncomingURLs.isEmpty else { return }
        let urls = bufferedNotificationIncomingURLs
        bufferedNotificationIncomingURLs.removeAll()
        for url in urls {
            let resolution = router.handleIncomingURL(url)
            if case .resolved(let resolvedURL) = resolution {
                container?.logger.log(
                    "Push deep link flushed from buffer to web: \(resolvedURL.absoluteString)"
                )
            }
            if case .rejected(let reason) = resolution {
                container?.logger.log("Push deep link flush rejected: \(reason)", level: .error)
            }
        }
    }

    /// Returns a startup deep link from notification sources with startup priority.
    /// Priority: launch-time buffered push > currently delivered notifications center list.
    @MainActor
    func consumeStartupNotificationDeepLinkURLIfAvailable() async -> URL? {
        if let bufferedURL = bufferedNotificationIncomingURLs.first {
            bufferedNotificationIncomingURLs.removeFirst()
            container?.logger.log("Startup push deep link consumed from launch buffer: \(bufferedURL.absoluteString)")
            return bufferedURL
        }

        let deliveredNotifications = await deliveredNotificationsSnapshot()
        guard !deliveredNotifications.isEmpty else { return nil }

        for notification in deliveredNotifications.reversed() {
            let userInfo = notification.request.content.userInfo
            guard let url = PushNotificationURLExtractor.urlForDeepLinkRouting(from: userInfo) else { continue }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
            container?.logger.log(
                "Startup push deep link consumed from delivered notifications: \(url.absoluteString)"
            )
            return url
        }

        container?.logger.log("Startup push deep link lookup: delivered notifications found but no resolvable URL")
        return nil
    }

    @MainActor
    private func routeNotificationDeepLinkIfPossible(from userInfo: [AnyHashable: Any], reason: String) {
        guard let url = PushNotificationURLExtractor.urlForDeepLinkRouting(from: userInfo) else {
            container?.logger.log("Push notification (\(reason)): no resolvable URL in userInfo")
            return
        }
        if let router = deepLinkRouter {
            let resolution = router.handleIncomingURL(url)
            if case .resolved(let resolvedURL) = resolution {
                container?.logger.log(
                    "Push notification (\(reason)) resolved to web: \(resolvedURL.absoluteString)"
                )
            }
            if case .rejected(let rejectReason) = resolution {
                container?.logger.log(
                    "Push notification (\(reason)) deep link rejected: \(rejectReason)",
                    level: .error
                )
            }
        } else {
            bufferedNotificationIncomingURLs.append(url)
            container?.logger.log(
                "Push notification (\(reason)) deep link buffered (router nil): \(url.absoluteString)"
            )
        }
    }

    /// Notifies AppsFlyer when the application becomes active; requests ATT only when status is not yet determined (system shows the prompt once).
    func applicationDidBecomeActive(_ application: UIApplication) {
        triggerTrackingAuthorizationFlowIfNeeded()
    }

    /// Public bridge for SwiftUI scene lifecycle to ensure the ATT/startup flow runs on app launch in scene-based environments.
    func triggerTrackingAuthorizationFlowIfNeeded() {
        requestTrackingAuthorizationIfNeededAndStartAppsFlyer()
    }

    /// Starts AppsFlyer once per launch and, on iOS 14+, requests ATT first when status is not determined.
    private func requestTrackingAuthorizationIfNeededAndStartAppsFlyer() {
        guard !hasStartedAppsFlyer else { return }
        guard #available(iOS 14, *) else {
            startAppsFlyerIfNeeded()
            return
        }

        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            startAppsFlyerIfNeeded()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            ATTrackingManager.requestTrackingAuthorization { _ in
                self?.container?.logger.log("ATT authorization request completed")
                self?.startAppsFlyerIfNeeded()
            }
        }
    }

    /// Ensures AppsFlyer starts once even if app becomes active multiple times quickly.
    private func startAppsFlyerIfNeeded() {
        guard !hasStartedAppsFlyer else { return }
        hasStartedAppsFlyer = true
        AppsFlyerLib.shared().start()
    }

    /// Logs critical runtime configuration values to simplify request troubleshooting.
    private func logRuntimeConfiguration(container: DependencyContainer) {
        let config = container.configuration
        let hasServerURL = !config.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasStoreId = !config.storeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasFirebaseProjectId = !config.firebaseProjectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAppsFlyerDevKey = !config.appsFlyerDevKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        container.logger.log(
            "Runtime config: serverURL=\(config.serverURL), hasStoreId=\(hasStoreId), hasFirebaseProjectId=\(hasFirebaseProjectId), hasAppsFlyerDevKey=\(hasAppsFlyerDevKey), isDebug=\(config.isDebug), hasServerURL=\(hasServerURL)"
        )
    }

    /// Receives APNS device token, registers it with Firebase Messaging,
    /// and retrieves the corresponding FCM token.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        container.fcmTokenDataSource.apnsStatus = "registered"
        container.fcmTokenDataSource.apnsErrorDescription = nil
        container.fcmTokenDataSource.isRegisteredForRemoteNotifications = application.isRegisteredForRemoteNotifications
        refreshNotificationAuthorizationStatus()
        container.logger.log("APNS device token received")

        Task { await refreshFCMToken(reason: "APNS device token received") }
    }

    /// Called when APNS registration fails. Helps diagnose missing push entitlement,
    /// provisioning profile issues, simulator limitations, or network problems.
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        container?.fcmTokenDataSource.apnsStatus = "failed"
        container?.fcmTokenDataSource.apnsErrorDescription = error.localizedDescription
        container?.fcmTokenDataSource.isRegisteredForRemoteNotifications = application.isRegisteredForRemoteNotifications
        refreshNotificationAuthorizationStatus()
        container?.logger.log(
            "APNS registration failed: \(error.localizedDescription)",
            level: .error
        )
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken,
              !fcmToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            container?.logger.log("MessagingDelegate returned empty FCM token", level: .error)
            return
        }
        container?.fcmTokenDataSource.token = fcmToken
        container?.logger.log("FCM token received from MessagingDelegate: \(fcmToken)")
    }

    private func refreshFCMToken(reason: String) async {
        do {
            let fcmToken = try await Messaging.messaging().token()
            container?.logger.log("FCM token received (\(reason)): \(fcmToken)")
            container?.fcmTokenDataSource.token = fcmToken
        } catch {
            container?.logger.log("Failed to get FCM token (\(reason)): \(error.localizedDescription)", level: .error)
        }
    }

    private func refreshNotificationAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let statusValue: String
            switch settings.authorizationStatus {
            case .notDetermined:
                statusValue = "notDetermined"
            case .denied:
                statusValue = "denied"
            case .authorized:
                statusValue = "authorized"
            case .provisional:
                statusValue = "provisional"
            case .ephemeral:
                statusValue = "ephemeral"
            @unknown default:
                statusValue = "unknown"
            }
            self?.container?.fcmTokenDataSource.notificationAuthorizationStatus = statusValue
        }
    }

    private func deliveredNotificationsSnapshot() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }

    /// Returns currently supported interface orientations based on orientation lock state.
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return orientationLock
    }

    /// Updates orientation lock and requests scene geometry update to apply rotation immediately.
    @MainActor
    func updateOrientationLock(_ lock: UIInterfaceOrientationMask) {
        orientationLock = lock
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else {
            UIViewController.attemptRotationToDeviceOrientation()
            return
        }
        let rootController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        rootController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        if #available(iOS 16.0, *) {
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: lock)
            windowScene.requestGeometryUpdate(preferences) { [weak self] error in
                self?.container?.logger.log(
                    "Failed to update geometry for orientation lock: \(error.localizedDescription)",
                    level: .error
                )
            }
        }
        UIViewController.attemptRotationToDeviceOrientation()
        DispatchQueue.main.async {
            rootController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    /// Handles universal links and forwards user activity to AppsFlyer.
    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        if let webpageURL = userActivity.webpageURL {
            Task { @MainActor in
                let resolution = deepLinkRouter?.handleIncomingURL(webpageURL)
                if case .resolved(let resolvedURL) = resolution {
                    container?.logger.log(
                        "DeepLink resolved in continueUserActivity to web: \(resolvedURL.absoluteString)"
                    )
                }
                if case .rejected(let reason) = resolution {
                    container?.logger.log("DeepLink rejected in continueUserActivity: \(reason)", level: .error)
                }
            }
        } else {
            container?.logger.log("DeepLink rejected in continueUserActivity: missing webpageURL", level: .error)
        }
        return true
    }

    /// Handles custom URL scheme links and routes them to the app-level deep link router.
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Task { @MainActor in
            let resolution = deepLinkRouter?.handleIncomingURL(url)
            if case .resolved(let resolvedURL) = resolution {
                container?.logger.log(
                    "DeepLink resolved in applicationOpenURL to web: \(resolvedURL.absoluteString)"
                )
            }
            if case .rejected(let reason) = resolution {
                container?.logger.log("DeepLink rejected in applicationOpenURL: \(reason)", level: .error)
            }
        }
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            self.routeNotificationDeepLinkIfPossible(from: userInfo, reason: "didReceiveNotificationResponse")
            completionHandler()
        }
    }
}
