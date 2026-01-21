import Foundation
import UserNotifications
import AppKit

// MARK: - Notification Manager

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    var didHandleNotificationClick = false

    // Action identifiers for permission request notifications
    private static let approveActionIdentifier = "APPROVE_ACTION"
    private static let denyActionIdentifier = "DENY_ACTION"
    private static let permissionCategoryIdentifier = "PERMISSION_REQUEST"

    override init() {
        super.init()
        center.delegate = self
        registerNotificationCategories()
    }

    /// Register notification categories with action buttons
    private func registerNotificationCategories() {
        let approveAction = UNNotificationAction(
            identifier: Self.approveActionIdentifier,
            title: L10n.Action.approve,
            options: [.foreground]
        )
        let denyAction = UNNotificationAction(
            identifier: Self.denyActionIdentifier,
            title: L10n.Action.deny,
            options: [.destructive]
        )

        let permissionCategory = UNNotificationCategory(
            identifier: Self.permissionCategoryIdentifier,
            actions: [approveAction, denyAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([permissionCategory])
        debugLog("Registered notification categories with approve/deny actions")
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

        // Set category for permission requests (shows approve/deny buttons)
        if content.canShowActionButtons {
            notificationContent.categoryIdentifier = Self.permissionCategoryIdentifier
            debugLog("Setting permission category for notification (terminal supports text input)")
        }

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
        debugLog("Notification action: \(response.actionIdentifier)")
        didHandleNotificationClick = true

        let userInfo = response.notification.request.content.userInfo
        debugLog("UserInfo: \(userInfo)")

        // Extract terminal info from userInfo
        let terminalInfo = extractTerminalInfo(from: userInfo)

        switch response.actionIdentifier {
        case Self.approveActionIdentifier:
            handlePermissionResponse(approved: true, terminalInfo: terminalInfo)
        case Self.denyActionIdentifier:
            handlePermissionResponse(approved: false, terminalInfo: terminalInfo)
        case UNNotificationDefaultActionIdentifier:
            // Default click action - activate terminal
            if let info = terminalInfo {
                debugLog("Terminal info: type=\(info.type), sessionId=\(info.sessionId ?? "nil"), tty=\(info.tty ?? "nil"), cwd=\(info.cwd ?? "nil")")
                TerminalActivator.activate(info)

                // Delete session file to prevent double activation
                // (new app instance might also try to handle saved session)
                try? FileManager.default.removeItem(atPath: "/tmp/.ai-notifier-last-session.json")
                debugLog("Deleted session file to prevent double activation")
            } else {
                debugLog("No terminal info in userInfo")
            }
        default:
            debugLog("Unknown action: \(response.actionIdentifier)")
        }

        completionHandler()
        // Keep running - don't exit after notification click
    }

    /// Extract TerminalInfo from notification userInfo
    private func extractTerminalInfo(from userInfo: [AnyHashable: Any]) -> TerminalInfo? {
        var terminalDict: [String: String] = [:]
        for (key, value) in userInfo {
            if let keyStr = key as? String, let valueStr = value as? String {
                terminalDict[keyStr] = valueStr
            }
        }

        guard !terminalDict.isEmpty else { return nil }
        return TerminalInfo.from(dictionary: terminalDict)
    }

    /// Handle permission approval or denial
    private func handlePermissionResponse(approved: Bool, terminalInfo: TerminalInfo?) {
        guard let info = terminalInfo else {
            debugLog("Cannot send permission response: no terminal info")
            return
        }

        let action = approved ? "approve" : "deny"
        debugLog("Permission \(action) for terminal: \(info.type)")

        let success: Bool
        if approved {
            success = TerminalInputHandler.sendApproval(to: info)
        } else {
            success = TerminalInputHandler.sendDenial(to: info)
        }

        if success {
            debugLog("Permission response sent successfully")
        } else {
            debugLog("Failed to send permission response")
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
