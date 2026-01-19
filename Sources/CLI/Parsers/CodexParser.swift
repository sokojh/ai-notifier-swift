import Foundation

// MARK: - Codex Parser

struct CodexParser {
    static func parse(data: [String: Any], title: String, cli: CLISource, terminalInfo: TerminalInfo) -> NotificationContent? {
        let eventType = data["type"] as? String ?? data["event"] as? String ?? data["event_type"] as? String ?? ""

        if eventType == "agent-turn-complete" {
            let response = extractResponse(from: data)
            return NotificationContent(
                title: title,
                subtitle: L10n.Notification.Subtitle.complete,
                body: response.isEmpty ? L10n.Notification.Body.checkResponse : response,
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        if eventType == "approval-requested" {
            // Always use localized message for consistent UI
            return NotificationContent(
                title: title,
                subtitle: L10n.Notification.Subtitle.permissionRequest,
                body: L10n.Notification.Body.permissionRequired,
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        // Default
        let response = extractResponse(from: data)
        return NotificationContent(
            title: title,
            subtitle: eventType.isEmpty ? L10n.Notification.Subtitle.notification : eventType,
            body: response.isEmpty ? L10n.Notification.Body.statusChanged : response,
            cli: cli,
            terminalInfo: terminalInfo
        )
    }

    private static func extractResponse(from data: [String: Any]) -> String {
        if let message = data["last-assistant-message"] as? String {
            return TextUtils.getPreviewText(message)
        }
        if let message = data["message"] as? String {
            return TextUtils.getPreviewText(message)
        }
        if let response = data["response"] as? String {
            return TextUtils.getPreviewText(response)
        }
        return ""
    }
}
