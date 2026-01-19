import Foundation

// MARK: - Hook Data Parser

struct HookDataParser {

    /// Detect CLI source from environment or data
    static func detectCLI(from data: [String: Any]?) -> CLISource {
        // Check environment variables
        if ProcessInfo.processInfo.environment["OPENCODE"] != nil {
            return .opencode
        }

        if ProcessInfo.processInfo.environment["CLAUDE_CODE"] != nil ||
           ProcessInfo.processInfo.environment["CLAUDE_PROJECT_ROOT"] != nil {
            return .claude
        }

        // Check for Gemini-specific fields or OpenCode cli field
        if let data = data {
            // Check cli field (OpenCode sends this)
            if let cli = data["cli"] as? String, cli == "opencode" {
                return .opencode
            }
            if data["llm_response"] != nil || data["modelResponse"] != nil || data["finishReason"] != nil {
                return .gemini
            }
            if data["event"] as? String == "agent-turn-complete" ||
               data["type"] as? String == "agent-turn-complete" {
                return .codex
            }

            // Check transcript_path
            if let transcriptPath = data["transcript_path"] as? String {
                if transcriptPath.contains("/.claude/") { return .claude }
                if transcriptPath.contains("/.gemini/") { return .gemini }
            }

            // Check hook_event_name for Claude/Gemini
            if data["hook_event_name"] != nil {
                let notificationType = data["notification_type"] as? String ?? ""
                if ["idle_prompt", "permission_prompt"].contains(notificationType) {
                    return .claude
                }
                if notificationType == "ToolPermission" {
                    return .gemini
                }
                if data["stop_hook_active"] != nil {
                    return .claude
                }
                if data["llm_response"] != nil {
                    return .gemini
                }
            }
        }

        // Default to claude
        return .claude
    }

    /// Parse notification content from hook data
    static func parseNotification(from data: [String: Any]?, cli: CLISource) -> NotificationContent? {
        // No data = no notification (e.g., app relaunched for notification click handling)
        guard let data = data else {
            return nil
        }

        let projectName = ProjectInfo.getProjectName(from: data)
        let title = "\(cli.displayName) - \(projectName)"

        // Capture terminal info for click-to-activate
        let cwd = data["cwd"] as? String
        let terminalInfo = TerminalInfo.capture(cwd: cwd)

        switch cli {
        case .claude:
            return ClaudeParser.parse(data: data, title: title, cli: cli, terminalInfo: terminalInfo)
        case .gemini:
            return GeminiParser.parse(data: data, title: title, cli: cli, terminalInfo: terminalInfo)
        case .codex:
            return CodexParser.parse(data: data, title: title, cli: cli, terminalInfo: terminalInfo)
        case .opencode:
            return OpenCodeParser.parse(data: data, title: title, cli: cli, terminalInfo: terminalInfo)
        case .unknown:
            return NotificationContent(
                title: title,
                subtitle: "알림",
                body: "상태가 변경되었습니다",
                cli: cli,
                terminalInfo: terminalInfo
            )
        }
    }
}
