import Foundation

// MARK: - Terminal Type

enum TerminalType: String {
    case iterm2 = "iTerm.app"
    case vscode = "vscode"
    case terminal = "Apple_Terminal"
    case ghostty = "ghostty"
    case warp = "WarpTerminal"
    case kitty = "kitty"
    case unknown = "unknown"

    static func detect() -> TerminalType {
        let env = ProcessInfo.processInfo.environment

        // Check TERM_PROGRAM first
        if let termProgram = env["TERM_PROGRAM"] {
            if let type = TerminalType(rawValue: termProgram) {
                return type
            }
        }

        // Kitty doesn't set TERM_PROGRAM, check KITTY_WINDOW_ID
        if env["KITTY_WINDOW_ID"] != nil {
            return .kitty
        }

        return .unknown
    }
}
