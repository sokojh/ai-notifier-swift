import Foundation
import UserNotifications
import AppKit

// MARK: - Setup Mode (Request Permission with GUI Dialog)

class SetupAppDelegate: NSObject, NSApplicationDelegate {
    private var loadingWindow: NSWindow?
    private var loadingIndicator: NSProgressIndicator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App is fully launched, now safe to request permissions
        debugLog("SetupAppDelegate: applicationDidFinishLaunching")

        // Show loading window immediately
        showLoadingWindow()

        // Small delay to ensure app is fully active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.requestPermissionAndInstallHooks()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        debugLog("SetupAppDelegate: applicationDidBecomeActive")

        // Check if this is a notification click (recent session file exists)
        let lastSessionFile = "/tmp/.ai-notifier-last-session.json"
        if FileManager.default.fileExists(atPath: lastSessionFile) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: lastSessionFile),
               let modDate = attrs[.modificationDate] as? Date,
               Date().timeIntervalSince(modDate) < 60 {
                if let data = FileManager.default.contents(atPath: lastSessionFile),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    debugLog("SetupAppDelegate: Found recent session, activating terminal")
                    let terminalInfo = TerminalInfo.from(dictionary: json)
                    TerminalActivator.activate(terminalInfo)
                    // Don't exit - let setup continue
                }
            }
        }
    }

    private func showLoadingWindow() {
        // Create a small loading window
        let windowRect = NSRect(x: 0, y: 0, width: 280, height: 100)
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "AI Notifier"
        window.center()
        window.isReleasedWhenClosed = false

        // Create content view
        let contentView = NSView(frame: windowRect)

        // Loading indicator
        let indicator = NSProgressIndicator(frame: NSRect(x: 120, y: 50, width: 40, height: 40))
        indicator.style = .spinning
        indicator.startAnimation(nil)
        contentView.addSubview(indicator)

        // Label
        let label = NSTextField(labelWithString: L10n.Setup.preparing)
        label.frame = NSRect(x: 0, y: 15, width: 280, height: 20)
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 13)
        contentView.addSubview(label)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)

        self.loadingWindow = window
        self.loadingIndicator = indicator
    }

    func hideLoadingWindow() {
        loadingIndicator?.stopAnimation(nil)
        loadingWindow?.close()
        loadingWindow = nil
    }

    private func requestPermissionAndInstallHooks() {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                // Hide loading window before showing dialogs
                self.hideLoadingWindow()

                if settings.authorizationStatus == .authorized {
                    // Already authorized, just install hooks
                    debugLog("Already authorized, installing hooks")
                    installHooksAndShowResult()
                } else {
                    // Request authorization
                    debugLog("Requesting authorization")
                    self.requestAuthorization()
                }
            }
        }
    }

    private func requestAuthorization() {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    debugLog("Authorization error: \(error.localizedDescription)")
                }

                if !granted {
                    let alert = NSAlert()
                    alert.messageText = "AI Notifier"
                    alert.informativeText = L10n.Setup.permissionRequired
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: L10n.Button.openSettings)
                    alert.addButton(withTitle: L10n.Button.close)

                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                    }
                    exit(1)
                }

                // Permission granted, continue to hook installation
                debugLog("Permission granted, installing hooks")
                installHooksAndShowResult()
            }
        }
    }
}

// MARK: - Setup Mode Functions

func runSetupMode() {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)

    let delegate = SetupAppDelegate()
    app.delegate = delegate

    // Activate app after delegate is set
    app.activate(ignoringOtherApps: true)

    debugLog("Starting setup mode app.run()")
    app.run()
}

func installHooksAndShowResult() {
    // Show loading window during hook installation
    let loadingWindow = createLoadingWindow(message: L10n.Setup.installingHooks)

    // Install hooks in background thread to avoid UI blocking
    DispatchQueue.global(qos: .userInitiated).async {
        let results = CLIHookInstaller.installAllHooks()

        // Build result message
        var messages: [String] = []
        messages.append(CLIHookInstaller.resultToString(results.claude, cliName: "Claude Code"))
        messages.append(CLIHookInstaller.resultToString(results.gemini, cliName: "Gemini CLI"))
        messages.append(CLIHookInstaller.resultToString(results.codex, cliName: "Codex CLI"))
        messages.append(CLIHookInstaller.resultToString(results.opencode, cliName: "OpenCode"))

        // Count installed
        let installedCount = [results.claude, results.gemini, results.codex, results.opencode].filter {
            if case .installed = $0 { return true }
            if case .alreadyInstalled = $0 { return true }
            return false
        }.count

        // Show result on main thread
        DispatchQueue.main.async {
            loadingWindow.close()

            let alert = NSAlert()
            alert.messageText = L10n.Setup.complete

            if installedCount > 0 {
                alert.informativeText = "\(L10n.Setup.permissionEnabled)\n\n\(L10n.Setup.cliHookSettings)\n• \(messages.joined(separator: "\n• "))\n\n\(L10n.Setup.setupSuccessMessage)\n\n\(L10n.Setup.ntfyTip)"
                alert.alertStyle = .informational
            } else {
                alert.informativeText = "\(L10n.Setup.permissionEnabled)\n\n\(L10n.Setup.cliHookSettings)\n• \(messages.joined(separator: "\n• "))\n\n\(L10n.Setup.noCLIInstalled)\n\n\(L10n.Setup.ntfyTip)"
                alert.alertStyle = .warning
            }

            alert.addButton(withTitle: L10n.Button.ok)
            alert.runModal()

            // Restart app in background mode
            // Dynamic activation policy change from .regular to .accessory
            // breaks menu bar click events, so we restart the app instead
            debugLog("Setup complete, restarting in background mode")

            // Mark as configured (so next double-click doesn't run setup again)
            let configuredFlag = NSString(string: "~/.ai-notifier-configured").expandingTildeInPath
            try? "".write(toFile: configuredFlag, atomically: true, encoding: .utf8)
            debugLog("Setup: Created configured flag")

            // Get the app bundle path
            let appPath = Bundle.main.bundlePath

            // Launch new instance with special flag to skip setup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                task.arguments = ["-a", appPath, "--args", "--background"]
                try? task.run()

                // Exit current setup instance
                debugLog("Setup: Launching background instance and exiting")
                exit(0)
            }
        }
    }
}

func createLoadingWindow(message: String) -> NSWindow {
    let windowRect = NSRect(x: 0, y: 0, width: 280, height: 100)
    let window = NSWindow(
        contentRect: windowRect,
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.title = "AI Notifier"
    window.center()
    window.isReleasedWhenClosed = false

    let contentView = NSView(frame: windowRect)

    let indicator = NSProgressIndicator(frame: NSRect(x: 120, y: 50, width: 40, height: 40))
    indicator.style = .spinning
    indicator.startAnimation(nil)
    contentView.addSubview(indicator)

    let label = NSTextField(labelWithString: message)
    label.frame = NSRect(x: 0, y: 15, width: 280, height: 20)
    label.alignment = .center
    label.font = NSFont.systemFont(ofSize: 13)
    contentView.addSubview(label)

    window.contentView = contentView
    window.makeKeyAndOrderFront(nil)

    return window
}
