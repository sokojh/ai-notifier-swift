import AppKit
import Foundation

// MARK: - Terminal Activator

struct TerminalActivator {
    static func activate(_ info: TerminalInfo) {
        switch info.type {
        case .iterm2:
            activateITerm2(sessionId: info.sessionId)
        case .vscode:
            activateVSCode(cwd: info.cwd)
        case .terminal:
            activateTerminalApp(tty: info.tty)
        case .ghostty:
            activateGhostty()
        case .warp:
            activateWarp(cwd: info.cwd)
        case .kitty:
            activateKitty(windowId: info.kittyWindowId)
        case .jetbrains:
            activateJetBrainsIDE(cwd: info.cwd)
        case .cursor:
            activateCursor(cwd: info.cwd)
        case .zed:
            activateZed(cwd: info.cwd)
        case .unknown:
            // Try to activate based on available info
            if info.sessionId != nil {
                activateITerm2(sessionId: info.sessionId)
            } else if info.tty != nil {
                activateTerminalApp(tty: info.tty)
            }
            // VSCode fallback 제거 - unknown 터미널은 무시
            debugLog("Unknown terminal type, skipping activation")
        }
    }

    private static func activateITerm2(sessionId: String?) {
        // AppleScript to activate iTerm2 and optionally select session
        if let sessionId = sessionId {
            // ITERM_SESSION_ID format: w0t0p0:UUID
            // Extract just the UUID part if present
            let uuid = sessionId.contains(":") ? String(sessionId.split(separator: ":").last ?? "") : sessionId
            if !uuid.isEmpty {
                let script = """
                tell application "iTerm2"
                    repeat with w in windows
                        repeat with t in tabs of w
                            repeat with s in sessions of t
                                if unique id of s is "\(uuid)" then
                                    select s
                                    select t
                                    set index of w to 1
                                end if
                            end repeat
                        end repeat
                    end repeat
                    activate
                end tell
                tell application "System Events"
                    set frontmost of process "iTerm2" to true
                end tell
                """
                runAppleScript(script)
                return
            }
        }

        // Fallback: just activate iTerm2
        runAppleScript("""
        tell application "iTerm2"
            activate
        end tell
        tell application "System Events"
            set frontmost of process "iTerm2" to true
        end tell
        """)
    }

    private static func activateVSCode(cwd: String?) {
        debugLog("activateVSCode called with cwd: \(cwd ?? "nil")")

        if let cwd = cwd {
            // Find VS Code CLI path (may not be in PATH)
            let codePaths = [
                "/usr/local/bin/code",
                "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
                "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code"
            ]

            var codePath: String? = nil
            for path in codePaths {
                if FileManager.default.fileExists(atPath: path) {
                    codePath = path
                    break
                }
            }

            if let codePath = codePath {
                debugLog("Running: \(codePath) \(cwd)")
                let task = Process()
                task.launchPath = codePath
                task.arguments = [cwd]
                task.standardOutput = FileHandle.nullDevice
                task.standardError = FileHandle.nullDevice
                do {
                    try task.run()
                    task.waitUntilExit()
                    debugLog("code command exit status: \(task.terminationStatus)")
                } catch {
                    debugLog("code command failed: \(error)")
                }
            } else {
                debugLog("VS Code CLI not found in any known location")
            }
        }

        // Bring VS Code to front
        debugLog("Running AppleScript to activate VS Code")
        runAppleScript("""
        tell application "Visual Studio Code"
            activate
        end tell
        tell application "System Events"
            set frontmost of process "Code" to true
        end tell
        """)

        // Focus terminal using VS Code URL scheme
        debugLog("Running vscode:// URL scheme for terminal focus")
        let urlTask = Process()
        urlTask.launchPath = "/usr/bin/open"
        urlTask.arguments = ["vscode://command/workbench.action.terminal.focus"]
        urlTask.standardOutput = FileHandle.nullDevice
        urlTask.standardError = FileHandle.nullDevice
        try? urlTask.run()
        debugLog("VS Code terminal focus command sent")
    }

    private static func activateTerminalApp(tty: String?) {
        var script = """
        tell application "Terminal"
        """

        if let tty = tty, !tty.isEmpty {
            // Select the specific tab by TTY
            script += """

                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(tty)" then
                            set selected tab of w to t
                            set index of w to 1
                        end if
                    end repeat
                end repeat
            """
        }

        script += """

            activate
        end tell
        tell application "System Events"
            set frontmost of process "Terminal" to true
        end tell
        """

        runAppleScript(script)
    }

    private static func activateGhostty() {
        // Ghostty doesn't have session selection API yet, just activate the app
        debugLog("Activating Ghostty...")
        runAppleScript("""
        tell application "Ghostty"
            activate
        end tell
        tell application "System Events"
            set frontmost of process "Ghostty" to true
        end tell
        """)
    }

    private static func activateWarp(cwd: String?) {
        debugLog("Activating Warp with cwd: \(cwd ?? "nil")")

        // Warp supports URL scheme but only for new tabs, not for selecting existing ones
        // Just activate the app - user will need to manually select the tab
        runAppleScript("""
        tell application "Warp"
            activate
        end tell
        tell application "System Events"
            set frontmost of process "Warp" to true
        end tell
        """)
    }

    private static func activateKitty(windowId: String?) {
        debugLog("Activating Kitty with windowId: \(windowId ?? "nil")")

        // Try to use kitten @ focus-window if remote control is available
        if let windowId = windowId {
            let task = Process()
            task.launchPath = "/usr/bin/env"
            task.arguments = ["kitten", "@", "focus-window", "--match", "id:\(windowId)"]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            do {
                try task.run()
                task.waitUntilExit()
                if task.terminationStatus == 0 {
                    debugLog("Kitty window focused via remote control")
                    return
                }
                debugLog("Kitty remote control failed (status: \(task.terminationStatus)), falling back to AppleScript")
            } catch {
                debugLog("Kitty remote control error: \(error), falling back to AppleScript")
            }
        }

        // Fallback: just activate Kitty app
        runAppleScript("""
        tell application "kitty"
            activate
        end tell
        tell application "System Events"
            set frontmost of process "kitty" to true
        end tell
        """)
    }

    // MARK: - IDE Terminal Activation (Window Only)

    private static func activateJetBrainsIDE(cwd: String?) {
        debugLog("Activating JetBrains IDE with cwd: \(cwd ?? "nil")")

        // JetBrains IDE CLI commands and app names (in order of popularity)
        // CLI paths: /usr/local/bin/<cli> or ~/Library/Application Support/JetBrains/Toolbox/scripts/<cli>
        let jetbrainsIDEs: [(cli: String, appName: String, processName: String)] = [
            ("phpstorm", "PhpStorm", "PhpStorm"),
            ("idea", "IntelliJ IDEA", "IntelliJ IDEA"),
            ("webstorm", "WebStorm", "WebStorm"),
            ("pycharm", "PyCharm", "PyCharm"),
            ("clion", "CLion", "CLion"),
            ("rubymine", "RubyMine", "RubyMine"),
            ("goland", "GoLand", "GoLand"),
            ("datagrip", "DataGrip", "DataGrip"),
            ("rider", "Rider", "Rider"),
            ("studio", "Android Studio", "Android Studio")
        ]

        // Find running JetBrains app
        let runningApps = NSWorkspace.shared.runningApplications
        for ide in jetbrainsIDEs {
            if runningApps.contains(where: { $0.localizedName?.contains(ide.appName) == true }) {
                debugLog("Found running JetBrains IDE: \(ide.appName)")

                // Try CLI first to open project folder (focuses existing window if already open)
                if let cwd = cwd, !cwd.isEmpty {
                    let cliPaths = [
                        "/usr/local/bin/\(ide.cli)",
                        "/opt/homebrew/bin/\(ide.cli)",
                        NSHomeDirectory() + "/Library/Application Support/JetBrains/Toolbox/scripts/\(ide.cli)"
                    ]

                    for path in cliPaths {
                        if FileManager.default.fileExists(atPath: path) {
                            debugLog("Running: \(path) \(cwd)")
                            let task = Process()
                            task.launchPath = path
                            task.arguments = [cwd]
                            task.standardOutput = FileHandle.nullDevice
                            task.standardError = FileHandle.nullDevice
                            do {
                                try task.run()
                                // CLI will focus the existing window, no need for AppleScript
                                return
                            } catch {
                                debugLog("JetBrains CLI failed: \(error)")
                            }
                            break
                        }
                    }
                }

                // Fallback: AppleScript activate
                runAppleScript("""
                tell application "\(ide.appName)"
                    activate
                end tell
                tell application "System Events"
                    set frontmost of process "\(ide.processName)" to true
                end tell
                """)
                return
            }
        }

        debugLog("No running JetBrains IDE found")
    }

    private static func activateCursor(cwd: String?) {
        debugLog("Activating Cursor with cwd: \(cwd ?? "nil")")

        // Try Cursor CLI first if cwd is available
        if let cwd = cwd, !cwd.isEmpty {
            let cursorPaths = [
                "/usr/local/bin/cursor",
                "/opt/homebrew/bin/cursor",
                "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
            ]

            for path in cursorPaths {
                if FileManager.default.fileExists(atPath: path) {
                    debugLog("Running: \(path) \(cwd)")
                    let task = Process()
                    task.launchPath = path
                    task.arguments = [cwd]
                    task.standardOutput = FileHandle.nullDevice
                    task.standardError = FileHandle.nullDevice
                    do {
                        try task.run()
                        // Don't wait - just fire and forget
                    } catch {
                        debugLog("Cursor CLI failed: \(error)")
                    }
                    break
                }
            }
        }

        // Activate via AppleScript
        runAppleScript("""
        tell application "Cursor"
            activate
        end tell
        tell application "System Events"
            set frontmost of process "Cursor" to true
        end tell
        """)
    }

    private static func activateZed(cwd: String?) {
        debugLog("Activating Zed with cwd: \(cwd ?? "nil")")

        // Try Zed CLI first if cwd is available
        if let cwd = cwd, !cwd.isEmpty {
            let zedPaths = [
                "/usr/local/bin/zed",
                "/opt/homebrew/bin/zed",
                "/Applications/Zed.app/Contents/MacOS/cli"
            ]

            for path in zedPaths {
                if FileManager.default.fileExists(atPath: path) {
                    debugLog("Running: \(path) \(cwd)")
                    let task = Process()
                    task.launchPath = path
                    task.arguments = [cwd]
                    task.standardOutput = FileHandle.nullDevice
                    task.standardError = FileHandle.nullDevice
                    do {
                        try task.run()
                        // Don't wait - just fire and forget
                    } catch {
                        debugLog("Zed CLI failed: \(error)")
                    }
                    break
                }
            }
        }

        // Activate via AppleScript
        runAppleScript("""
        tell application "Zed"
            activate
        end tell
        tell application "System Events"
            set frontmost of process "Zed" to true
        end tell
        """)
    }

    private static func runAppleScript(_ script: String) {
        debugLog("Running AppleScript: \(script.prefix(100))...")
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]

        let errorPipe = Pipe()
        task.standardOutput = FileHandle.nullDevice
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if let errorStr = String(data: errorData, encoding: .utf8), !errorStr.isEmpty {
                debugLog("AppleScript error: \(errorStr)")
            }
            debugLog("AppleScript exit code: \(task.terminationStatus)")
        } catch {
            debugLog("AppleScript failed to run: \(error)")
        }
    }
}
