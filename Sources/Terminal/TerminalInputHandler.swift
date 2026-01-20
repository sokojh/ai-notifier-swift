import Foundation
import AppKit

// MARK: - Terminal Input Handler

/// Handles sending text input to terminal sessions via AppleScript
/// Used for permission approval/denial from notification actions
struct TerminalInputHandler {

    // MARK: - Response Constants

    // Based on actual CLI testing:
    // - Codex: y/1 = approve, esc = deny (3 options)
    // - Gemini: 1 = Allow once, esc/4 = deny (4 options)
    // - Claude: 1 = Yes, 3 = No, esc = cancel (3 options)
    //
    // Common pattern: "1" selects first option (approve) in all CLIs
    // For deny: esc key works universally, but sending "esc" as text doesn't work
    // So we send the escape key code via System Events

    static let approveResponse = "1"  // First option in all CLIs

    // MARK: - Public Methods

    /// Send approval response to terminal (selects option 1)
    /// - Parameter info: Terminal info containing session identifiers
    /// - Returns: True if text was sent successfully
    static func sendApproval(to info: TerminalInfo) -> Bool {
        return sendText(approveResponse, to: info)
    }

    /// Send denial response to terminal (sends Escape key)
    /// - Parameter info: Terminal info containing session identifiers
    /// - Returns: True if key was sent successfully
    static func sendDenial(to info: TerminalInfo) -> Bool {
        guard info.type.supportsTextInput else {
            debugLog("Terminal type \(info.type) does not support text input")
            return false
        }

        // First activate the terminal, then send Escape key
        switch info.type {
        case .iterm2:
            return sendEscapeToITerm2(sessionId: info.sessionId)
        case .terminal:
            return sendEscapeToTerminalApp(tty: info.tty)
        default:
            return false
        }
    }

    /// Send arbitrary text to terminal
    /// - Parameters:
    ///   - text: Text to send
    ///   - info: Terminal info containing session identifiers
    /// - Returns: True if text was sent successfully
    static func sendText(_ text: String, to info: TerminalInfo) -> Bool {
        guard info.type.supportsTextInput else {
            debugLog("Terminal type \(info.type) does not support text input")
            return false
        }

        switch info.type {
        case .iterm2:
            return sendTextToITerm2(text, sessionId: info.sessionId)
        case .terminal:
            return sendTextToTerminalApp(text, tty: info.tty)
        default:
            return false
        }
    }

    // MARK: - Private Methods

    private static func sendTextToITerm2(_ text: String, sessionId: String?) -> Bool {
        guard let sessionId = sessionId else {
            debugLog("iTerm2: No session ID available")
            return false
        }

        // ITERM_SESSION_ID format: w0t0p0:UUID - extract just the UUID part
        let uuid = sessionId.contains(":") ? String(sessionId.split(separator: ":").last ?? "") : sessionId
        guard !uuid.isEmpty else {
            debugLog("iTerm2: Could not extract UUID from session ID")
            return false
        }

        // Escape special characters for AppleScript
        let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedUUID = uuid.replacingOccurrences(of: "\"", with: "\\\"")

        // Use keystroke via System Events for more reliable input
        // write text adds newline which may not work for all CLI prompts
        let script = """
        tell application "iTerm2"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if unique id of s is "\(escapedUUID)" then
                            select t
                            tell s to select
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        delay 0.1
        tell application "System Events"
            keystroke "\(escapedText)"
        end tell
        return true
        """

        let success = runAppleScript(script)
        debugLog("iTerm2 text input: \(success ? "success" : "failed") for session \(uuid)")
        return success
    }

    private static func sendTextToTerminalApp(_ text: String, tty: String?) -> Bool {
        guard let tty = tty else {
            debugLog("Terminal.app: No TTY available")
            return false
        }

        // Escape special characters for AppleScript
        let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedTTY = tty.replacingOccurrences(of: "\"", with: "\\\"")

        // For Terminal.app, we use "do script" which types the text
        // Note: "do script" creates a new command execution, equivalent to typing and pressing Enter
        let script = """
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is "\(escapedTTY)" then
                        do script "\(escapedText)" in t
                        return true
                    end if
                end repeat
            end repeat
        end tell
        return false
        """

        let success = runAppleScript(script)
        debugLog("Terminal.app text input: \(success ? "success" : "failed") for tty \(tty)")
        return success
    }

    private static func runAppleScript(_ script: String) -> Bool {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if let error = error {
                debugLog("AppleScript error: \(error)")
                return false
            }
            // Check if script returned true
            if result.booleanValue {
                return true
            }
        }
        return false
    }

    // MARK: - Escape Key Handlers

    private static func sendEscapeToITerm2(sessionId: String?) -> Bool {
        guard let sessionId = sessionId else {
            debugLog("iTerm2: No session ID available for escape key")
            return false
        }

        // ITERM_SESSION_ID format: w0t0p0:UUID - extract just the UUID part
        let uuid = sessionId.contains(":") ? String(sessionId.split(separator: ":").last ?? "") : sessionId
        guard !uuid.isEmpty else {
            debugLog("iTerm2: Could not extract UUID from session ID for escape key")
            return false
        }

        let escapedUUID = uuid.replacingOccurrences(of: "\"", with: "\\\"")

        // First activate iTerm2 and select the session, then send escape key
        let script = """
        tell application "iTerm2"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if unique id of s is "\(escapedUUID)" then
                            select t
                            tell s to select
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        delay 0.1
        tell application "System Events"
            key code 53
        end tell
        return true
        """

        let success = runAppleScript(script)
        debugLog("iTerm2 escape key: \(success ? "success" : "failed") for session \(uuid)")
        return success
    }

    private static func sendEscapeToTerminalApp(tty: String?) -> Bool {
        guard let tty = tty else {
            debugLog("Terminal.app: No TTY available for escape key")
            return false
        }

        let escapedTTY = tty.replacingOccurrences(of: "\"", with: "\\\"")

        // First activate Terminal and select the tab, then send escape key
        let script = """
        tell application "Terminal"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is "\(escapedTTY)" then
                        set selected of t to true
                        set frontmost of w to true
                    end if
                end repeat
            end repeat
        end tell
        delay 0.1
        tell application "System Events"
            key code 53
        end tell
        return true
        """

        let success = runAppleScript(script)
        debugLog("Terminal.app escape key: \(success ? "success" : "failed") for tty \(tty)")
        return success
    }
}
