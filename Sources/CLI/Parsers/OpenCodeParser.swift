import Foundation

// MARK: - OpenCode Parser

struct OpenCodeParser {
    static func parse(data: [String: Any], title: String, cli: CLISource, terminalInfo: TerminalInfo) -> NotificationContent? {
        let hookName = data["hook_event_name"] as? String ?? ""
        let projectName = data["project_name"] as? String
        let responsePreview = data["response_preview"] as? String

        // Include project name in title if available
        let displayTitle = projectName != nil ? "\(title) - \(projectName!)" : title

        switch hookName {
        case "complete", "Stop":  // "Stop" for backwards compatibility
            // Show response preview in body if available
            let body = responsePreview?.isEmpty == false ? responsePreview! : L10n.Notification.Body.taskComplete
            return NotificationContent(
                title: displayTitle,
                subtitle: L10n.Notification.Subtitle.complete,
                body: body,
                cli: cli,
                terminalInfo: terminalInfo
            )
        case "error":
            return NotificationContent(
                title: displayTitle,
                subtitle: L10n.Notification.Subtitle.error,
                body: L10n.Notification.Body.sessionError,
                cli: cli,
                terminalInfo: terminalInfo
            )
        case "permission":
            return NotificationContent(
                title: displayTitle,
                subtitle: L10n.Notification.Subtitle.permissionNeeded,
                body: L10n.Notification.Body.approvalNeeded,
                cli: cli,
                terminalInfo: terminalInfo,
                isPermissionRequest: true
            )
        default:
            return NotificationContent(
                title: displayTitle,
                subtitle: L10n.Notification.Subtitle.notification,
                body: L10n.Notification.Body.statusChanged,
                cli: cli,
                terminalInfo: terminalInfo
            )
        }
    }
}
