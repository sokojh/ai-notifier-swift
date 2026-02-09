import Foundation
import AppKit

// MARK: - Status Bar Controller

class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private var updateMenuItem: NSMenuItem?

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func setup() {
        guard statusItem == nil else {
            debugLog("StatusBar: Already setup, skipping")
            return
        }

        debugLog("StatusBar: Creating status item on thread \(Thread.isMainThread ? "main" : "background")")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        debugLog("StatusBar: statusItem created = \(statusItem != nil)")

        if let button = statusItem?.button {
            // Use SF Symbol for the icon
            if let image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "AI Notifier") {
                image.isTemplate = true
                button.image = image
                debugLog("StatusBar: SF Symbol icon set")
            } else {
                // Fallback to text if SF Symbol not available
                button.title = "🔔"
                debugLog("StatusBar: Fallback emoji icon set")
            }
            button.toolTip = "AI Notifier"
        } else {
            debugLog("StatusBar: ERROR - button is nil!")
        }

        setupMenu()
        debugLog("StatusBar: Setup complete, menu = \(statusItem?.menu != nil)")
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Title item (disabled, for information)
        let titleItem = NSMenuItem(title: "AI Notifier", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        // Version item (disabled, for information)
        let versionItem = NSMenuItem(
            title: L10n.Update.currentVersion(UpdateManager.shared.currentVersion),
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(NSMenuItem.separator())

        // Settings item
        let settingsItem = NSMenuItem(title: L10n.Menu.settings, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Check for Updates item
        let updateItem = NSMenuItem(title: L10n.Menu.checkForUpdates, action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)
        self.updateMenuItem = updateItem

        menu.addItem(NSMenuItem.separator())

        // Quit item
        let quitItem = NSMenuItem(title: L10n.Menu.quit, action: #selector(quitApp), keyEquivalent: "q")
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

    @objc private func checkForUpdates() {
        debugLog("StatusBar: Checking for updates")

        // Update menu item to show checking status
        updateMenuItem?.title = L10n.Update.checking
        updateMenuItem?.isEnabled = false

        UpdateManager.shared.checkForUpdates { [weak self] result in
            DispatchQueue.main.async {
                // Restore menu item
                self?.updateMenuItem?.title = L10n.Menu.checkForUpdates
                self?.updateMenuItem?.isEnabled = true

                switch result {
                case .success(let release):
                    if let release = release {
                        self?.showUpdateAvailableAlert(release: release)
                    } else {
                        self?.showUpToDateAlert()
                    }
                case .failure(let error):
                    self?.showUpdateCheckFailedAlert(error: error)
                }
            }
        }
    }

    private func showUpdateAvailableAlert(release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = L10n.Update.available
        alert.informativeText = L10n.Update.newVersionAvailable(release.tagName)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.Update.downloadNow)
        alert.addButton(withTitle: L10n.Update.later)

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            UpdateManager.shared.openDownloadPage()
        }
    }

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.Update.upToDate
        alert.informativeText = L10n.Update.currentVersion(UpdateManager.shared.currentVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.Button.ok)

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showUpdateCheckFailedAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n.Update.checkFailed
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.Button.ok)

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Update Badge

    func showUpdateBadge() {
        guard let button = statusItem?.button else { return }

        // Update icon to show badge
        if let image = NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: "AI Notifier - Update Available") {
            image.isTemplate = true
            button.image = image
        }

        debugLog("StatusBar: Update badge shown")
    }

    func hideUpdateBadge() {
        guard let button = statusItem?.button else { return }

        // Restore normal icon
        if let image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "AI Notifier") {
            image.isTemplate = true
            button.image = image
        }

        debugLog("StatusBar: Update badge hidden")
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
        window.title = L10n.Settings.windowTitle
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        setupContent()
    }

    private func setupContent() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)

        // Tab-like header (for future expansion)
        let headerLabel = NSTextField(labelWithString: L10n.Settings.ntfyHeader)
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
        let cancelButton = NSButton(title: L10n.Button.cancel, target: self, action: #selector(cancelSettings))
        cancelButton.frame = NSRect(x: 170, y: 10, width: 80, height: 30)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"  // Escape key
        contentView.addSubview(cancelButton)

        let saveButton = NSButton(title: L10n.Button.save, target: self, action: #selector(saveSettings))
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
        let ntfySettingsFromView = ntfyView.createSettings()

        // Save config (preserve existing auth because settings UI does not edit auth)
        var config = AppConfig.load()
        let existingAuth = config.ntfy?.auth
        if var ntfySettings = ntfySettingsFromView {
            ntfySettings.auth = existingAuth
            config.ntfy = ntfySettings
        } else {
            config.ntfy = nil
        }

        do {
            try config.save()
            debugLog("Settings saved successfully")

            // Reload NtfyConfig singleton
            NtfyConfig.shared.reload()

            // Show success feedback
            if let window = window {
                let alert = NSAlert()
                alert.messageText = L10n.Alert.settingsSaved
                alert.informativeText = ntfySettingsFromView != nil
                    ? L10n.Alert.ntfyEnabled
                    : L10n.Alert.ntfyDisabled
                alert.alertStyle = .informational
                alert.addButton(withTitle: L10n.Button.ok)
                alert.beginSheetModal(for: window) { _ in
                    self.close()
                }
            }
        } catch {
            debugLog("Failed to save settings: \(error.localizedDescription)")

            if let window = window {
                let alert = NSAlert()
                alert.messageText = L10n.Alert.settingsSaveFailed
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: L10n.Button.ok)
                alert.beginSheetModal(for: window)
            }
        }
    }
}
