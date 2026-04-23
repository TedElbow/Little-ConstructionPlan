import Foundation
import UserNotifications
import FirebaseMessaging

/// <summary>
/// Notification service extension to handle rich push notifications,
/// including downloading and attaching images sent via Leanplum (LP_URL key).
/// </summary>
class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    /// <summary>
    /// Called when a push notification is received. Downloads rich media if provided and attaches it.
    /// </summary>
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {

        let imageKey = "LP_URL"
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else { return }

        let userInfo = request.content.userInfo

        // If no LP_URL key exists, let Firebase helper process rich media from FCM payload
        guard let attachmentMedia = userInfo[imageKey] as? String,
              let mediaUrl = URL(string: attachmentMedia) else {
            Messaging.serviceExtension().populateNotificationContent(
                bestAttemptContent,
                withContentHandler: contentHandler
            )
            return
        }

        // Download and attach rich media
        URLSession(configuration: .default).downloadTask(with: mediaUrl) { temporaryLocation, response, error in
            if let error = error {
                print("Leanplum: Error downloading rich push: \(error.localizedDescription)")
                contentHandler(bestAttemptContent)
                return
            }

            guard let tempLocation = temporaryLocation,
                  let mimeType = response?.mimeType else {
                contentHandler(bestAttemptContent)
                return
            }

            let fileType = self.determineType(fileType: mimeType)
            let fileName = tempLocation.lastPathComponent.appending(fileType)
            let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

            do {
                try FileManager.default.moveItem(at: tempLocation, to: destination)
                let attachment = try UNNotificationAttachment(identifier: "", url: destination, options: nil)
                bestAttemptContent.attachments = [attachment]
                contentHandler(bestAttemptContent)

                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
            } catch {
                print("Leanplum: Error attaching rich push: \(error)")
                contentHandler(bestAttemptContent)
            }
        }.resume()
    }

    /// <summary>
    /// Called when the extension is about to expire; delivers the best attempt content.
    /// </summary>
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    /// <summary>
    /// Determines file extension based on MIME type for attachments.
    /// </summary>
    func determineType(fileType: String) -> String {
        switch fileType {
        case "image/jpeg": return ".jpg"
        case "image/gif": return ".gif"
        case "image/png": return ".png"
        default: return ".tmp"
        }
    }
}
