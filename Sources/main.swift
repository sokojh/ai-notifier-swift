import Foundation
import AppKit
import Darwin

// MARK: - Main Entry Point

func main() {
    // Check for explicit setup mode first
    if CommandLine.arguments.contains("--setup") || CommandLine.arguments.contains("-s") {
        runSetupMode()
        return
    }

    // Check if running as hook
    let hookMode = AppController.isHookMode()
    let isHookMode = hookMode.hasStdin || hookMode.hasArgv

    // First run auto-setup only when NOT in hook mode (user double-clicked app)
    if !isHookMode {
        let configuredFlag = NSString(string: "~/.ai-notifier-configured").expandingTildeInPath
        let isFirstRun = !FileManager.default.fileExists(atPath: configuredFlag)
        if isFirstRun {
            runSetupMode()
            try? "".write(toFile: configuredFlag, atomically: true, encoding: .utf8)
            return
        }
    }

    // Check for URL scheme activation (ai-notifier://activate?...)
    if CommandLine.arguments.count > 1 {
        let arg = CommandLine.arguments[1]
        if arg.hasPrefix("ai-notifier://") {
            debugLog("=== URL scheme activation ===")
            AppController.handleURLScheme(arg)
            exit(0)
        }
    }

    debugLog("=== ai-notifier started ===")
    debugLog("Arguments count: \(CommandLine.arguments.count)")
    debugLog("Arguments: \(CommandLine.arguments)")

    // Parse input data
    let inputData = AppController.parseInputData()

    // Detect CLI source
    let cli = HookDataParser.detectCLI(from: inputData)
    debugLog("Detected CLI: \(cli.rawValue)")

    // Parse notification content
    guard let content = HookDataParser.parseNotification(from: inputData, cli: cli) else {
        // parseNotification returned nil - could be:
        // 1. Debounced (inputData not empty but skipped)
        // 2. Launched from notification click (inputData empty)
        // 3. Launched directly by user (double-click from Finder/DMG)

        // If we had input data but parseNotification returned nil, it was debounced - exit silently
        if inputData != nil && !(inputData?.isEmpty ?? true) {
            debugLog("Debounced - exiting silently")
            return
        }

        // Check for saved session file (notification click)
        if AppController.handleSavedSession() {
            exit(0)
        }

        // Check if launched directly (TTY) - user double-clicked the app
        let isDirectLaunch = isatty(FileHandle.standardInput.fileDescriptor) != 0
        if isDirectLaunch {
            // Only run setup if not already configured
            let configuredFlag = NSString(string: "~/.ai-notifier-configured").expandingTildeInPath
            if !FileManager.default.fileExists(atPath: configuredFlag) {
                debugLog("Direct launch detected (not configured) - running setup mode")
                runSetupMode()
                try? "".write(toFile: configuredFlag, atomically: true, encoding: .utf8)
            } else {
                debugLog("Direct launch detected (already configured) - running setup mode for settings")
                runSetupMode()
            }
            return
        }

        // No input data, no recent session, not direct launch - nothing to do
        debugLog("No input data and no recent session - exiting")
        return
    }

    debugLog("Notification: title=\(content.title), subtitle=\(content.subtitle), body=\(content.body.prefix(50))...")
    debugLog("TerminalInfo: type=\(content.terminalInfo.type), sessionId=\(content.terminalInfo.sessionId ?? "nil"), tty=\(content.terminalInfo.tty ?? "nil"), cwd=\(content.terminalInfo.cwd ?? "nil")")

    // Save terminal info for notification click handling
    AppController.saveSession(terminalInfo: content.terminalInfo)

    // Send notification and run event loop
    AppController.sendNotificationAndRun(content: content)
}

// Run main
main()
