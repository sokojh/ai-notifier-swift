import Foundation
import UserNotifications
import AppKit

// MARK: - Notification Manager

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    var didHandleNotificationClick = false

    override init() {
        super.init()
        center.delegate = self
    }

    func sendNotification(
        content: NotificationContent,
        completion: @escaping (Bool) -> Void
    ) {
        let ntfyEnabled = NtfyConfig.shared.enabled
        let totalTargets = ntfyEnabled ? 2 : 1
        var completedCount = 0
        var successCount = 0
        let lock = NSLock()

        let checkCompletion = { (success: Bool) in
            lock.lock()
            completedCount += 1
            if success { successCount += 1 }
            let done = completedCount >= totalTargets
            let result = successCount > 0
            lock.unlock()

            if done {
                completion(result)
            }
        }

        // 1. Send to ntfy (if enabled) - parallel
        if ntfyEnabled {
            NtfyClient.send(content: content) { success in
                debugLog("ntfy delivery: \(success ? "success" : "failed")")
                checkCompletion(success)
            }
        }

        // 2. Send native macOS notification - parallel
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                fputs("Authorization error: \(error.localizedDescription)\n", stderr)
                checkCompletion(false)
                return
            }

            guard granted else {
                fputs("Notification permission denied. Please enable in System Settings > Notifications > AI Notifier\n", stderr)
                checkCompletion(false)
                return
            }

            // Permission granted, now send notification
            self.deliverNotification(content: content) { success in
                checkCompletion(success)
            }
        }
    }

    private func deliverNotification(
        content: NotificationContent,
        completion: @escaping (Bool) -> Void
    ) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = content.title
        notificationContent.subtitle = content.subtitle
        notificationContent.body = content.body
        notificationContent.sound = .default

        // Store terminal info in userInfo for click handling
        notificationContent.userInfo = content.terminalInfo.toDictionary()

        // Add icon as attachment if available
        if let iconURL = getIconURL(for: content.cli) {
            let tempDir = FileManager.default.temporaryDirectory
            let tempIconURL = tempDir.appendingPathComponent("ai-notifier-\(UUID().uuidString).png")

            do {
                try FileManager.default.copyItem(at: iconURL, to: tempIconURL)
                let attachment = try UNNotificationAttachment(
                    identifier: "icon",
                    url: tempIconURL,
                    options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
                )
                notificationContent.attachments = [attachment]
            } catch {
                // Icon attachment failed, continue without icon
            }
        }

        let identifier = "ai-notifier-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: notificationContent, trigger: nil)

        center.add(request) { error in
            if let error = error {
                fputs("Notification error: \(error.localizedDescription)\n", stderr)
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        debugLog("Notification clicked! Action: \(response.actionIdentifier)")
        didHandleNotificationClick = true

        // Handle notification click
        let userInfo = response.notification.request.content.userInfo
        debugLog("UserInfo: \(userInfo)")

        // Extract terminal info from userInfo (handle [AnyHashable: Any] type)
        var terminalDict: [String: String] = [:]
        for (key, value) in userInfo {
            if let keyStr = key as? String, let valueStr = value as? String {
                terminalDict[keyStr] = valueStr
            }
        }

        if !terminalDict.isEmpty {
            let terminalInfo = TerminalInfo.from(dictionary: terminalDict)
            debugLog("Terminal info: type=\(terminalInfo.type), sessionId=\(terminalInfo.sessionId ?? "nil"), tty=\(terminalInfo.tty ?? "nil"), cwd=\(terminalInfo.cwd ?? "nil")")
            TerminalActivator.activate(terminalInfo)
        } else {
            debugLog("No terminal info in userInfo")
        }

        completionHandler()

        // Exit after handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    private func getIconURL(for cli: CLISource) -> URL? {
        let bundle = Bundle.main

        if let iconPath = bundle.path(forResource: cli.iconName, ofType: "png") {
            return URL(fileURLWithPath: iconPath)
        }

        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let resourcesURL = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(cli.iconName).png")

        if FileManager.default.fileExists(atPath: resourcesURL.path) {
            return resourcesURL
        }

        return nil
    }
}
