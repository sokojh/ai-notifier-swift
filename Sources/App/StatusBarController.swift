import Foundation
import AppKit

// MARK: - Status Bar Controller

class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func setup() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Use SF Symbol for the icon
            if let image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "AI Notifier") {
                image.isTemplate = true
                button.image = image
            } else {
                // Fallback to text if SF Symbol not available
                button.title = "🔔"
            }
            button.toolTip = "AI Notifier"
        }

        setupMenu()
        debugLog("StatusBar: Setup complete")
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Title item (disabled, for information)
        let titleItem = NSMenuItem(title: "AI Notifier", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Settings item
        let settingsItem = NSMenuItem(title: "설정...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit item
        let quitItem = NSMenuItem(title: "종료", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func openSettings() {
        debugLog("StatusBar: Opening settings")

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        debugLog("StatusBar: Quit requested")
        NSApp.terminate(nil)
    }

    // MARK: - Cleanup

    func remove() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSWindowController {
    private var ntfySettingsView: NtfySettingsView?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "AI Notifier 설정"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        setupContent()
    }

    private func setupContent() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)

        // Tab-like header (for future expansion)
        let headerLabel = NSTextField(labelWithString: "ntfy 푸시 알림")
        headerLabel.frame = NSRect(x: 20, y: 255, width: 200, height: 20)
        headerLabel.font = NSFont.boldSystemFont(ofSize: 14)
        contentView.addSubview(headerLabel)

        // Separator
        let separator = NSBox()
        separator.frame = NSRect(x: 20, y: 245, width: 320, height: 1)
        separator.boxType = .separator
        contentView.addSubview(separator)

        // Ntfy settings view
        let ntfyView = NtfySettingsView(frame: NSRect(x: 10, y: 50, width: 340, height: 190))
        ntfyView.loadCurrentSettings()
        contentView.addSubview(ntfyView)
        self.ntfySettingsView = ntfyView

        // Buttons
        let cancelButton = NSButton(title: "취소", target: self, action: #selector(cancelSettings))
        cancelButton.frame = NSRect(x: 170, y: 10, width: 80, height: 30)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"  // Escape key
        contentView.addSubview(cancelButton)

        let saveButton = NSButton(title: "저장", target: self, action: #selector(saveSettings))
        saveButton.frame = NSRect(x: 260, y: 10, width: 80, height: 30)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"  // Enter key
        contentView.addSubview(saveButton)

        window.contentView = contentView
    }

    @objc private func cancelSettings() {
        close()
    }

    @objc private func saveSettings() {
        guard let ntfyView = ntfySettingsView else {
            close()
            return
        }

        // Get settings from view
        let ntfySettings = ntfyView.createSettings()

        // Save config
        var config = AppConfig.load()
        config.ntfy = ntfySettings

        do {
            try config.save()
            debugLog("Settings saved successfully")

            // Reload NtfyConfig singleton
            NtfyConfig.shared.reload()

            // Show success feedback
            if let window = window {
                let alert = NSAlert()
                alert.messageText = "설정 저장 완료"
                alert.informativeText = ntfySettings != nil
                    ? "ntfy 알림이 활성화되었습니다."
                    : "ntfy 알림이 비활성화되었습니다."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "확인")
                alert.beginSheetModal(for: window) { _ in
                    self.close()
                }
            }
        } catch {
            debugLog("Failed to save settings: \(error.localizedDescription)")

            if let window = window {
                let alert = NSAlert()
                alert.messageText = "설정 저장 실패"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "확인")
                alert.beginSheetModal(for: window)
            }
        }
    }
}
