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
                subtitle: "응답 완료",
                body: response.isEmpty ? "응답을 확인하세요" : response,
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        // Notification event
        if hookName == "Notification" {
            if notificationType == "idle_prompt" {
                return NotificationContent(
                    title: title,
                    subtitle: "입력 대기",
                    body: "사용자 입력을 기다리고 있습니다",
                    cli: cli,
                    terminalInfo: terminalInfo
                )
            }

            if notificationType == "permission_prompt" {
                return NotificationContent(
                    title: title,
                    subtitle: "권한 요청",
                    body: message ?? "권한 승인이 필요합니다",
                    cli: cli,
                    terminalInfo: terminalInfo
                )
            }

            return NotificationContent(
                title: title,
                subtitle: notificationType.isEmpty ? "알림" : notificationType,
                body: message ?? "응답을 확인하세요",
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        // Default - treat as stop
        let response = extractResponse(from: data)
        return NotificationContent(
            title: title,
            subtitle: "응답 완료",
            body: response.isEmpty ? "응답을 확인하세요" : response,
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
