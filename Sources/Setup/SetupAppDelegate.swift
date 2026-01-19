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
        let label = NSTextField(labelWithString: "설정 준비 중...")
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
                    alert.informativeText = "알림 권한이 필요합니다.\n\n시스템 설정 > 알림 > AI Notifier에서 '알림 허용'을 켜주세요."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "설정 열기")
                    alert.addButton(withTitle: "닫기")

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
    // Step 2: Install CLI hooks
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

    let alert = NSAlert()
    alert.messageText = "AI Notifier 설정 완료"

    if installedCount > 0 {
        alert.informativeText = "알림 권한: 활성화됨\n\nCLI 훅 설정:\n• \(messages.joined(separator: "\n• "))\n\n이제 CLI 응답 완료 시 알림을 받을 수 있습니다!\n\n💡 메뉴바 🔔 아이콘에서 ntfy 푸시 알림을 설정할 수 있습니다."
        alert.alertStyle = .informational
    } else {
        alert.informativeText = "알림 권한: 활성화됨\n\nCLI 훅 설정:\n• \(messages.joined(separator: "\n• "))\n\n설치된 CLI가 없습니다. Claude Code, Gemini CLI, Codex CLI, 또는 OpenCode를 설치한 후 다시 실행해주세요.\n\n💡 메뉴바 🔔 아이콘에서 ntfy 푸시 알림을 설정할 수 있습니다."
        alert.alertStyle = .warning
    }

    alert.addButton(withTitle: "확인")
    alert.runModal()
    exit(0)
}
