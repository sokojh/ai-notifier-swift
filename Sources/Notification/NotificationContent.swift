import Foundation

// MARK: - Notification Content

struct NotificationContent {
    let title: String      // "Claude - project-name"
    let subtitle: String   // "Complete" / "Permission Request"
    let body: String       // Response preview
    let cli: CLISource
    let terminalInfo: TerminalInfo
}
