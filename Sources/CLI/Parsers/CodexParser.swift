import Foundation

// MARK: - Codex Parser

struct CodexParser {
    static func parse(data: [String: Any], title: String, cli: CLISource, terminalInfo: TerminalInfo) -> NotificationContent? {
        let eventType = data["type"] as? String ?? data["event"] as? String ?? data["event_type"] as? String ?? ""

        if eventType == "agent-turn-complete" {
            let response = extractResponse(from: data)
            return NotificationContent(
                title: title,
                subtitle: "응답 완료",
                body: response.isEmpty ? "응답을 확인하세요" : response,
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        if eventType == "approval-requested" {
            let message = data["message"] as? String
            return NotificationContent(
                title: title,
                subtitle: "권한 요청",
                body: message ?? "권한 승인이 필요합니다",
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        // Default
        let response = extractResponse(from: data)
        return NotificationContent(
            title: title,
            subtitle: eventType.isEmpty ? "알림" : eventType,
            body: response.isEmpty ? "상태가 변경되었습니다" : response,
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
