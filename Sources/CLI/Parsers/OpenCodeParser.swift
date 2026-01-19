import Foundation

// MARK: - OpenCode Parser

struct OpenCodeParser {
    static func parse(data: [String: Any], title: String, cli: CLISource, terminalInfo: TerminalInfo) -> NotificationContent? {
        let hookName = data["hook_event_name"] as? String ?? ""
        let projectName = data["project_name"] as? String
        let responsePreview = data["response_preview"] as? String

        // 프로젝트 이름이 있으면 타이틀에 포함
        let displayTitle = projectName != nil ? "\(title) - \(projectName!)" : title

        switch hookName {
        case "complete", "Stop":  // "Stop"은 하위호환
            // 응답 미리보기가 있으면 본문에 표시
            let body = responsePreview?.isEmpty == false ? responsePreview! : "작업이 완료되었습니다"
            return NotificationContent(
                title: displayTitle,
                subtitle: "응답 완료",
                body: body,
                cli: cli,
                terminalInfo: terminalInfo
            )
        case "error":
            return NotificationContent(
                title: displayTitle,
                subtitle: "오류 발생",
                body: "세션에서 오류가 발생했습니다",
                cli: cli,
                terminalInfo: terminalInfo
            )
        case "permission":
            return NotificationContent(
                title: displayTitle,
                subtitle: "권한 필요",
                body: "승인이 필요합니다",
                cli: cli,
                terminalInfo: terminalInfo
            )
        default:
            return NotificationContent(
                title: displayTitle,
                subtitle: "알림",
                body: "상태가 변경되었습니다",
                cli: cli,
                terminalInfo: terminalInfo
            )
        }
    }
}
