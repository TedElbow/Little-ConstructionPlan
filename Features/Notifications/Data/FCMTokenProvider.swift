import Foundation
import FirebaseMessaging

/// Provides FCM push token: uses cached value from data source first,
/// then requests from Firebase Messaging if needed.
final class FCMTokenProvider: PushTokenProviderProtocol {

    private let fcmTokenDataSource: FCMTokenDataSourceProtocol
    private let logger: Logging
    private let retryAttempts: Int
    private let retryDelayNanoseconds: UInt64

    init(
        fcmTokenDataSource: FCMTokenDataSourceProtocol,
        logger: Logging,
        retryAttempts: Int = 12,
        retryDelay: TimeInterval = 1.0
    ) {
        self.fcmTokenDataSource = fcmTokenDataSource
        self.logger = logger
        self.retryAttempts = max(1, retryAttempts)
        self.retryDelayNanoseconds = max(0, UInt64(retryDelay * 1_000_000_000))
    }

    func getToken() async -> String? {
        if let cached = fcmTokenDataSource.token {
            logger.log("FCMTokenProvider: using cached FCM token")
            return cached
        }

        if fcmTokenDataSource.apnsStatus == "pending" {
            logger.log(
                "FCMTokenProvider: skipping FCM token fetch because APNS status is pending",
                level: .error
            )
            return nil
        }

        if fcmTokenDataSource.apnsStatus == "failed" {
            logger.log(
                "FCMTokenProvider: skipping FCM token fetch because APNS registration failed: \(fcmTokenDataSource.apnsErrorDescription ?? "unknown error")",
                level: .error
            )
            return nil
        }

        var attempt = 0
        while attempt < retryAttempts {
            if attempt > 0 && retryDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
            }

            let attemptNumber = attempt + 1
            if let token = await requestFirebaseToken(attemptNumber: attemptNumber) {
                fcmTokenDataSource.token = token
                logger.log("FCMTokenProvider: received FCM token on attempt \(attemptNumber)")
                return token
            }
            attempt += 1
        }

        logger.log(
            "FCMTokenProvider: failed to get FCM token after \(retryAttempts) attempts",
            level: .error
        )
        return nil
    }

    private func requestFirebaseToken(attemptNumber: Int) async -> String? {
        await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, error in
                if let error {
                    self.logger.log(
                        "FCMTokenProvider: attempt \(attemptNumber) failed with Firebase error: \(error.localizedDescription)",
                        level: .error
                    )
                } else if token == nil {
                    self.logger.log(
                        "FCMTokenProvider: attempt \(attemptNumber) returned nil token without explicit Firebase error",
                        level: .error
                    )
                }
                continuation.resume(returning: token)
            }
        }
    }
}
