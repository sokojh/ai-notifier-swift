import Foundation

// MARK: - Notification Content

struct NotificationContent {
    let title: String      // "Claude - project-name"
    let subtitle: String   // "응답 완료" / "권한 요청" / "입력 대기"
    let body: String       // Response preview
    let cli: CLISource
    let terminalInfo: TerminalInfo
}
