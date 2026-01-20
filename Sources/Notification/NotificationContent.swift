import Foundation

// MARK: - Notification Content

struct NotificationContent {
    let title: String           // "Claude - project-name"
    let subtitle: String        // "Complete" / "Permission Request"
    let body: String            // Response preview
    let cli: CLISource
    let terminalInfo: TerminalInfo
    let isPermissionRequest: Bool  // Whether this is a permission request notification

    /// Whether action buttons (approve/deny) can be shown for this notification
    /// Only supported for terminals with text input support (iTerm2, Terminal.app)
    var canShowActionButtons: Bool {
        return isPermissionRequest && terminalInfo.type.supportsTextInput
    }

    init(
        title: String,
        subtitle: String,
        body: String,
        cli: CLISource,
        terminalInfo: TerminalInfo,
        isPermissionRequest: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.cli = cli
        self.terminalInfo = terminalInfo
        self.isPermissionRequest = isPermissionRequest
    }
}
