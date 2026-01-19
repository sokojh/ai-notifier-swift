import Foundation
import AppKit

// MARK: - Ntfy Settings View

class NtfySettingsView: NSView {
    // MARK: - UI Components

    private let enableCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let serverLabel = NSTextField(labelWithString: "")
    private let serverField = NSTextField()
    private let topicLabel = NSTextField(labelWithString: "")
    private let topicField = NSTextField()
    private let testButton = NSButton(title: "", target: nil, action: nil)
    private let testStatusLabel = NSTextField(labelWithString: "")

    // MARK: - Properties

    var isEnabled: Bool {
        get { enableCheckbox.state == .on }
        set { enableCheckbox.state = newValue ? .on : .off; updateFieldsEnabled() }
    }

    var server: String {
        get { serverField.stringValue }
        set { serverField.stringValue = newValue }
    }

    var topic: String {
        get { topicField.stringValue }
        set { topicField.stringValue = newValue }
    }

    private var onTestTapped: (() -> Void)?

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // Enable checkbox
        enableCheckbox.title = L10n.Settings.enableNtfy
        enableCheckbox.target = self
        enableCheckbox.action = #selector(enableCheckboxChanged)
        enableCheckbox.frame = NSRect(x: 20, y: 150, width: 250, height: 20)
        addSubview(enableCheckbox)

        // Server label
        serverLabel.stringValue = L10n.Settings.server
        serverLabel.frame = NSRect(x: 20, y: 115, width: 50, height: 20)
        serverLabel.alignment = .right
        addSubview(serverLabel)

        // Server field
        serverField.frame = NSRect(x: 75, y: 113, width: 225, height: 24)
        serverField.placeholderString = "https://ntfy.sh"
        serverField.stringValue = "https://ntfy.sh"
        addSubview(serverField)

        // Topic label
        topicLabel.stringValue = L10n.Settings.topic
        topicLabel.frame = NSRect(x: 20, y: 80, width: 50, height: 20)
        topicLabel.alignment = .right
        addSubview(topicLabel)

        // Topic field
        topicField.frame = NSRect(x: 75, y: 78, width: 225, height: 24)
        topicField.placeholderString = "my-ai-notifier-topic"
        addSubview(topicField)

        // Test button
        testButton.title = L10n.Settings.test
        testButton.frame = NSRect(x: 75, y: 40, width: 80, height: 28)
        testButton.bezelStyle = .rounded
        testButton.target = self
        testButton.action = #selector(testButtonTapped)
        addSubview(testButton)

        // Test status label
        testStatusLabel.frame = NSRect(x: 160, y: 43, width: 140, height: 20)
        testStatusLabel.font = NSFont.systemFont(ofSize: 12)
        testStatusLabel.textColor = .secondaryLabelColor
        addSubview(testStatusLabel)

        // Info label
        let infoLabel = NSTextField(wrappingLabelWithString: L10n.Settings.ntfyInfo)
        infoLabel.frame = NSRect(x: 20, y: 5, width: 280, height: 30)
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        addSubview(infoLabel)

        // Initial state
        updateFieldsEnabled()
    }

    // MARK: - Actions

    @objc private func enableCheckboxChanged() {
        updateFieldsEnabled()
    }

    @objc private func testButtonTapped() {
        testConnection()
    }

    private func updateFieldsEnabled() {
        let enabled = enableCheckbox.state == .on
        serverField.isEnabled = enabled
        topicField.isEnabled = enabled
        testButton.isEnabled = enabled

        // Visual feedback
        serverField.textColor = enabled ? .textColor : .disabledControlTextColor
        topicField.textColor = enabled ? .textColor : .disabledControlTextColor
    }

    // MARK: - Test Connection

    private func testConnection() {
        let server = serverField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let topic = topicField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !server.isEmpty else {
            showTestResult(success: false, message: L10n.NtfyError.enterServerURL)
            return
        }

        guard !topic.isEmpty else {
            showTestResult(success: false, message: L10n.NtfyError.enterTopic)
            return
        }

        // Show loading state
        testButton.isEnabled = false
        testStatusLabel.stringValue = L10n.Settings.testing
        testStatusLabel.textColor = .secondaryLabelColor

        NtfyClient.testConnection(server: server, topic: topic) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Only re-enable if checkbox is still on
                self.testButton.isEnabled = self.enableCheckbox.state == .on
                switch result {
                case .success:
                    self.showTestResult(success: true, message: L10n.Settings.connectionSuccess)
                case .failure(let error):
                    self.showTestResult(success: false, message: error.localizedDescription)
                }
            }
        }
    }

    private func showTestResult(success: Bool, message: String) {
        testStatusLabel.stringValue = message
        testStatusLabel.textColor = success ? .systemGreen : .systemRed
    }

    // MARK: - Load/Save Settings

    func loadCurrentSettings() {
        let config = AppConfig.load()
        if let ntfy = config.ntfy {
            isEnabled = ntfy.enabled
            server = ntfy.server
            topic = ntfy.topic
        } else {
            isEnabled = false
            server = "https://ntfy.sh"
            topic = ""
        }
    }

    func createSettings() -> NtfySettings? {
        guard isEnabled else {
            return nil
        }

        let serverValue = server.trimmingCharacters(in: .whitespacesAndNewlines)
        let topicValue = topic.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !serverValue.isEmpty, !topicValue.isEmpty else {
            return nil
        }

        return NtfySettings.simple(enabled: true, server: serverValue, topic: topicValue)
    }
}
