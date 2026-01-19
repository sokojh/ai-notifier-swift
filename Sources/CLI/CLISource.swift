import Foundation

// MARK: - CLI Types

enum CLISource: String, CaseIterable {
    case claude = "claude"
    case gemini = "gemini"
    case codex = "codex"
    case opencode = "opencode"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .codex: return "Codex"
        case .opencode: return "OpenCode"
        case .unknown: return "AI"
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "claude-logo"
        case .gemini: return "gemini-logo"
        case .codex: return "codex-logo"
        case .opencode: return "opencode-logo"
        case .unknown: return "claude-logo"
        }
    }
}
