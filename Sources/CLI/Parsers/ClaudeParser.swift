import Foundation

// MARK: - Claude Parser

struct ClaudeParser {
    static func parse(data: [String: Any], title: String, cli: CLISource, terminalInfo: TerminalInfo) -> NotificationContent? {
        let hookName = data["hook_event_name"] as? String ?? data["hook_name"] as? String ?? ""
        let notificationType = data["notification_type"] as? String ?? ""
        let message = data["message"] as? String

        // Stop event
        if hookName == "Stop" || data["stop_hook_active"] as? Bool == true {
            let response = extractResponse(from: data)
            return NotificationContent(
                title: title,
                subtitle: L10n.Notification.Subtitle.complete,
                body: response.isEmpty ? L10n.Notification.Body.checkResponse : response,
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        // Notification event (only permission_prompt)
        if hookName == "Notification" {
            // Skip idle_prompt - too frequent and unnecessary
            if notificationType == "idle_prompt" {
                return nil
            }

            if notificationType == "permission_prompt" {
                // Always use localized message for consistent UI
                // Claude Code sends English message, so we override it
                return NotificationContent(
                    title: title,
                    subtitle: L10n.Notification.Subtitle.permissionRequest,
                    body: L10n.Notification.Body.permissionRequired,
                    cli: cli,
                    terminalInfo: terminalInfo
                )
            }

            return NotificationContent(
                title: title,
                subtitle: notificationType.isEmpty ? L10n.Notification.Subtitle.notification : notificationType,
                body: message ?? L10n.Notification.Body.checkResponse,
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        // Default - treat as stop
        let response = extractResponse(from: data)
        return NotificationContent(
            title: title,
            subtitle: L10n.Notification.Subtitle.complete,
            body: response.isEmpty ? L10n.Notification.Body.checkResponse : response,
            cli: cli,
            terminalInfo: terminalInfo
        )
    }

    private static func extractResponse(from data: [String: Any]) -> String {
        // Try transcript array in JSON
        if let transcript = data["transcript"] as? [[String: Any]] {
            for item in transcript.reversed() {
                if item["type"] as? String == "assistant" {
                    if let message = item["message"] as? [String: Any],
                       let content = message["content"] as? [[String: Any]] {
                        for block in content.reversed() {
                            if block["type"] as? String == "text",
                               let text = block["text"] as? String {
                                return TextUtils.getPreviewText(text)
                            }
                        }
                    }
                }
            }
        }

        // Try transcript_path (read from file)
        if let transcriptPath = data["transcript_path"] as? String,
           FileManager.default.fileExists(atPath: transcriptPath) {
            if let content = try? String(contentsOfFile: transcriptPath, encoding: .utf8) {
                let lines = content.split(separator: "\n").reversed()
                for line in lines {
                    if let lineData = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                       json["type"] as? String == "assistant" {
                        if let message = json["message"] as? [String: Any],
                           let msgContent = message["content"] as? [[String: Any]] {
                            for block in msgContent.reversed() {
                                if block["type"] as? String == "text",
                                   let text = block["text"] as? String {
                                    return TextUtils.getPreviewText(text)
                                }
                            }
                        }
                    }
                }
            }
        }

        return ""
    }
}
