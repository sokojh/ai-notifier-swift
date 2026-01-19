import Foundation

// MARK: - Terminal Info (for click-to-activate)

struct TerminalInfo {
    let type: TerminalType
    let sessionId: String?      // iTerm2 ITERM_SESSION_ID
    let cwd: String?            // Working directory for VS Code
    let tty: String?            // TTY device for Terminal.app (e.g., /dev/ttys001)
    let kittyWindowId: String?  // Kitty KITTY_WINDOW_ID

    static func capture(cwd: String? = nil) -> TerminalInfo {
        let env = ProcessInfo.processInfo.environment
        return TerminalInfo(
            type: TerminalType.detect(),
            sessionId: env["ITERM_SESSION_ID"],
            cwd: cwd ?? env["PWD"],
            tty: env["TTY"] ?? getCurrentTTY(),
            kittyWindowId: env["KITTY_WINDOW_ID"]
        )
    }

    private static func getCurrentTTY() -> String? {
        // Try to get TTY from tty command
        let task = Process()
        task.launchPath = "/usr/bin/tty"
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty && output != "not a tty" {
                return output
            }
        } catch {}
        return nil
    }

    func toDictionary() -> [String: String] {
        var dict: [String: String] = ["terminalType": type.rawValue]
        if let sessionId = sessionId { dict["sessionId"] = sessionId }
        if let cwd = cwd { dict["cwd"] = cwd }
        if let tty = tty { dict["tty"] = tty }
        if let kittyWindowId = kittyWindowId { dict["kittyWindowId"] = kittyWindowId }
        return dict
    }

    static func from(dictionary: [String: String]) -> TerminalInfo {
        return TerminalInfo(
            type: TerminalType(rawValue: dictionary["terminalType"] ?? "") ?? .unknown,
            sessionId: dictionary["sessionId"],
            cwd: dictionary["cwd"],
            tty: dictionary["tty"],
            kittyWindowId: dictionary["kittyWindowId"]
        )
    }
}
