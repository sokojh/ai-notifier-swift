import Foundation
import AppKit
import Darwin

// MARK: - App Controller

struct AppController {

    /// Check if running as hook mode
    static func isHookMode() -> (hasStdin: Bool, hasArgv: Bool) {
        // Check stdin data
        let hasStdinData: Bool = {
            if isatty(FileHandle.standardInput.fileDescriptor) != 0 {
                return false  // TTY means interactive terminal, not hook
            }
            // Non-TTY: check if actual data is available using poll()
            let stdinFd = FileHandle.standardInput.fileDescriptor
            var pollFd = pollfd(fd: stdinFd, events: Int16(POLLIN), revents: 0)
            let pollResult = poll(&pollFd, 1, 50)  // 50ms timeout
            return pollResult > 0 && (pollFd.revents & Int16(POLLIN)) != 0
        }()

        // Check argv data
        let hasArgvData: Bool = {
            guard CommandLine.arguments.count > 1 else { return false }
            let arg = CommandLine.arguments[1]
            // Skip flags and URL schemes
            if arg.hasPrefix("-") || arg.hasPrefix("ai-notifier://") { return false }
            // Check if it looks like JSON
            return arg.hasPrefix("{")
        }()

        return (hasStdinData, hasArgvData)
    }

    /// Parse input data from stdin or argv
    static func parseInputData() -> [String: Any]? {
        var inputData: [String: Any]? = nil

        // 1. Try command line arguments first (Codex passes JSON as argv)
        if CommandLine.arguments.count > 1 {
            let arg = CommandLine.arguments[1]
            debugLog("Arg[1]: \(arg.prefix(200))...")
            // Skip if it's a flag
            if !arg.hasPrefix("-") {
                if let data = arg.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    inputData = json
                    debugLog("Parsed from argv: \(json.keys)")
                }
            }
        }

        // 2. Fall back to stdin (Claude, Gemini)
        if inputData == nil {
            debugLog("Checking stdin... isatty=\(isatty(FileHandle.standardInput.fileDescriptor))")
            // Check if stdin has data (non-TTY)
            if isatty(FileHandle.standardInput.fileDescriptor) == 0 {
                // Use poll() to check if data is available without blocking
                let stdinFd = FileHandle.standardInput.fileDescriptor
                var pollFd = pollfd(fd: stdinFd, events: Int16(POLLIN), revents: 0)
                let pollResult = poll(&pollFd, 1, 100)  // 100ms timeout

                if pollResult > 0 && (pollFd.revents & Int16(POLLIN)) != 0 {
                    // Data is available, read it
                    if let inputString = readLine(strippingNewline: false) {
                        var fullInput = inputString
                        while let line = readLine(strippingNewline: false) {
                            fullInput += line
                        }
                        debugLog("Stdin received: \(fullInput.prefix(200))...")

                        if let data = fullInput.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            inputData = json
                            debugLog("Parsed from stdin: \(json.keys)")
                        }
                    }
                } else {
                    debugLog("No stdin data available (poll returned \(pollResult))")
                }
            }
        }

        return inputData
    }

    /// Handle URL scheme activation
    static func handleURLScheme(_ urlString: String) {
        debugLog("Handling URL scheme: \(urlString)")

        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            debugLog("Invalid URL")
            return
        }

        // Parse query parameters
        var params: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value {
                params[item.name] = value
            }
        }

        debugLog("URL params: \(params)")

        // Reconstruct terminal info from URL params
        let terminalInfo = TerminalInfo(
            type: TerminalType(rawValue: params["type"] ?? "") ?? .unknown,
            sessionId: params["sessionId"],
            cwd: params["cwd"],
            tty: params["tty"],
            kittyWindowId: params["kittyWindowId"]
        )

        debugLog("Activating terminal: \(terminalInfo.type)")
        TerminalActivator.activate(terminalInfo)
    }

    /// Handle saved session file (for notification click)
    static func handleSavedSession() -> Bool {
        let lastSessionFile = "/tmp/.ai-notifier-last-session.json"
        if FileManager.default.fileExists(atPath: lastSessionFile) {
            // Check if session file is recent (within 60 seconds) - likely a notification click
            if let attrs = try? FileManager.default.attributesOfItem(atPath: lastSessionFile),
               let modDate = attrs[.modificationDate] as? Date,
               Date().timeIntervalSince(modDate) < 60 {
                if let data = FileManager.default.contents(atPath: lastSessionFile),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    debugLog("Found recent saved session: \(json)")
                    let terminalInfo = TerminalInfo.from(dictionary: json)
                    debugLog("Activating terminal from saved session: type=\(terminalInfo.type)")
                    TerminalActivator.activate(terminalInfo)

                    // Give time for activation to complete
                    Thread.sleep(forTimeInterval: 0.5)
                    return true
                }
            } else {
                debugLog("Session file exists but is old (>60s)")
            }
        }
        return false
    }

    /// Save terminal info for notification click handling
    static func saveSession(terminalInfo: TerminalInfo) {
        let lastSessionFile = "/tmp/.ai-notifier-last-session.json"
        let sessionDict = terminalInfo.toDictionary()
        if let jsonData = try? JSONSerialization.data(withJSONObject: sessionDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? jsonString.write(toFile: lastSessionFile, atomically: true, encoding: .utf8)
            debugLog("Saved session to \(lastSessionFile)")
        }
    }

    /// Send notification and keep app running for click handling
    static func sendNotificationAndRun(content: NotificationContent) {
        // Check if another instance is already running
        let isFirstInstance = !ProcessManager.isAnotherInstanceRunning()

        // Send notification
        NotificationManager.shared.sendNotification(content: content) { success in
            debugLog("Notification sent: \(success ? "success" : "failed")")

            // If another instance is running, exit after sending notification
            if !isFirstInstance {
                debugLog("Another instance is running, exiting after notification sent")
                // Small delay to ensure notification is delivered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    exit(0)
                }
            }
        }

        // Only the first instance should run in background
        if isFirstInstance {
            debugLog("First instance - starting background run loop")

            // NOTE: Removed setsid() - it was breaking menu bar click events
            // The menu bar icon will still work, but Terminal window might
            // briefly flash when notification is sent

            // Write PID file and setup cleanup
            ProcessManager.writePIDFile()
            ProcessManager.setupCleanup()

            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)  // Hide from dock

            // Setup status bar icon with settings menu
            StatusBarController.shared.setup()

            app.run()
        } else {
            // Wait for notification to be sent, then exit
            debugLog("Not first instance - waiting for notification then exit")
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))
        }
    }
}
