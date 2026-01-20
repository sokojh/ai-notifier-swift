import Foundation

// MARK: - Terminal Type

enum TerminalType: String {
    // Full support (tab/session selection)
    case iterm2 = "iTerm.app"
    case terminal = "Apple_Terminal"

    // Partial support (window activation with cwd)
    case vscode = "vscode"
    case kitty = "kitty"
    case cursor = "Cursor"
    case zed = "Zed"
    // Note: Windsurf removed - no reliable detection method found
    // (VS Code fork, likely inherits TERM_PROGRAM=vscode, no unique env var documented)

    // App activation only
    case ghostty = "ghostty"
    case warp = "WarpTerminal"
    case jetbrains = "JetBrains"

    case unknown = "unknown"

    /// Whether this terminal supports programmatic text input via AppleScript
    var supportsTextInput: Bool {
        switch self {
        case .iterm2, .terminal:
            return true
        default:
            return false
        }
    }

    /// Detect terminal type from environment variables
    static func detect() -> TerminalType {
        let env = ProcessInfo.processInfo.environment

        // JetBrains IDE detection (verified: TERMINAL_EMULATOR=JetBrains-JediTerm)
        // Source: JetBrains/jediterm GitHub Issue #253
        if let termEmulator = env["TERMINAL_EMULATOR"], termEmulator.contains("JetBrains") {
            return .jetbrains
        }

        // Cursor detection (verified: CURSOR_AGENT or CURSOR_CLI)
        // Warning: TERM_PROGRAM=vscode (inherited from VS Code), so we use Cursor-specific env vars
        // Source: getcursor/cursor GitHub Issue #1760
        if env["CURSOR_AGENT"] != nil || env["CURSOR_CLI"] != nil {
            return .cursor
        }

        // Zed detection (verified: ZED_TERM=true)
        // Source: zed-industries/zed GitHub Issue #4571
        if env["ZED_TERM"] == "true" {
            return .zed
        }

        // Kitty detection (KITTY_WINDOW_ID)
        if env["KITTY_WINDOW_ID"] != nil {
            return .kitty
        }

        // Check TERM_PROGRAM for standard terminals
        if let termProgram = env["TERM_PROGRAM"] {
            if let type = TerminalType(rawValue: termProgram) {
                return type
            }
        }

        return .unknown
    }
}
