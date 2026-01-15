import Foundation
import UserNotifications
import AppKit

// MARK: - CLI Types

enum CLISource: String, CaseIterable {
    case claude = "claude"
    case gemini = "gemini"
    case codex = "codex"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .gemini: return "Gemini CLI"
        case .codex: return "Codex CLI"
        case .unknown: return "AI CLI"
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "claude-logo"
        case .gemini: return "gemini-logo"
        case .codex: return "codex-logo"
        case .unknown: return "claude-logo"
        }
    }
}

// MARK: - Hook Event Types

enum HookEvent {
    case stop(transcript: String?)
    case notification(type: String, message: String?)
    case agentTurn(response: String?)
    case afterModel(text: String?)
    case unknown
}

// MARK: - Hook Data Parser

struct HookDataParser {

    /// Detect CLI source from environment or data
    static func detectCLI(from data: [String: Any]?) -> CLISource {
        // Check environment variables
        if ProcessInfo.processInfo.environment["CLAUDE_CODE"] != nil ||
           ProcessInfo.processInfo.environment["CLAUDE_PROJECT_ROOT"] != nil {
            return .claude
        }

        // Check for Gemini-specific fields
        if let data = data {
            if data["modelResponse"] != nil || data["finishReason"] != nil {
                return .gemini
            }
            if data["event"] as? String == "agent-turn-complete" {
                return .codex
            }
        }

        // Check process info
        let parentProcess = ProcessInfo.processInfo.processName
        if parentProcess.lowercased().contains("gemini") {
            return .gemini
        }
        if parentProcess.lowercased().contains("codex") {
            return .codex
        }

        // Default to claude (most common)
        return .claude
    }

    /// Parse hook event from JSON data
    static func parseEvent(from data: [String: Any]?, cli: CLISource) -> HookEvent {
        guard let data = data else {
            return .stop(transcript: nil)
        }

        switch cli {
        case .claude:
            return parseClaudeEvent(data)
        case .gemini:
            return parseGeminiEvent(data)
        case .codex:
            return parseCodexEvent(data)
        case .unknown:
            return .unknown
        }
    }

    // MARK: - Claude Parsing

    private static func parseClaudeEvent(_ data: [String: Any]) -> HookEvent {
        // Check for notification event
        if let hookName = data["hook_name"] as? String {
            if hookName == "Notification" {
                let notificationType = data["notification_type"] as? String ?? ""
                return .notification(type: notificationType, message: nil)
            }
        }

        // Stop event - extract transcript
        if let transcript = data["transcript"] as? [[String: Any]] {
            let lastAssistantMessage = extractLastAssistantMessage(from: transcript)
            return .stop(transcript: lastAssistantMessage)
        }

        // Try to get stop_hook_active
        if data["stop_hook_active"] as? Bool == true {
            if let transcript = data["transcript"] as? [[String: Any]] {
                let lastAssistantMessage = extractLastAssistantMessage(from: transcript)
                return .stop(transcript: lastAssistantMessage)
            }
            return .stop(transcript: nil)
        }

        return .stop(transcript: nil)
    }

    private static func extractLastAssistantMessage(from transcript: [[String: Any]]) -> String? {
        // Find last assistant message
        for item in transcript.reversed() {
            if item["type"] as? String == "assistant" {
                if let message = item["message"] as? [String: Any],
                   let content = message["content"] as? [[String: Any]] {
                    // Extract text from content blocks
                    for block in content.reversed() {
                        if block["type"] as? String == "text",
                           let text = block["text"] as? String {
                            return truncateMessage(text, maxLength: 100)
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Gemini Parsing

    private static func parseGeminiEvent(_ data: [String: Any]) -> HookEvent {
        // Check finish reason
        if let finishReason = data["finishReason"] as? String,
           finishReason != "STOP" {
            return .unknown // Skip non-final responses
        }

        // Extract text from modelResponse
        if let modelResponse = data["modelResponse"] as? [String: Any],
           let candidates = modelResponse["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            return .afterModel(text: truncateMessage(text, maxLength: 100))
        }

        return .afterModel(text: nil)
    }

    // MARK: - Codex Parsing

    private static func parseCodexEvent(_ data: [String: Any]) -> HookEvent {
        if let event = data["event"] as? String {
            if event == "agent-turn-complete" {
                let response = data["response"] as? String
                return .agentTurn(response: truncateMessage(response, maxLength: 100))
            }
            if event == "approval-requested" {
                return .notification(type: "approval", message: data["message"] as? String)
            }
        }
        return .agentTurn(response: nil)
    }

    // MARK: - Helpers

    private static func truncateMessage(_ text: String?, maxLength: Int) -> String? {
        guard let text = text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxLength {
            return trimmed
        }
        return String(trimmed.prefix(maxLength)) + "..."
    }
}

// MARK: - Project Info

struct ProjectInfo {
    static func getProjectName() -> String {
        // Try CLAUDE_PROJECT_ROOT first
        if let projectRoot = ProcessInfo.processInfo.environment["CLAUDE_PROJECT_ROOT"] {
            return URL(fileURLWithPath: projectRoot).lastPathComponent
        }

        // Try PWD
        if let pwd = ProcessInfo.processInfo.environment["PWD"] {
            return URL(fileURLWithPath: pwd).lastPathComponent
        }

        // Fallback to current directory
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent
    }
}

// MARK: - Notification Manager

class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    func sendNotification(
        cli: CLISource,
        title: String,
        subtitle: String,
        body: String,
        completion: @escaping (Bool) -> Void
    ) {
        // First, request authorization
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                fputs("Authorization error: \(error.localizedDescription)\n", stderr)
                completion(false)
                return
            }

            guard granted else {
                fputs("Notification permission denied. Please enable in System Settings > Notifications > AI Notifier\n", stderr)
                completion(false)
                return
            }

            // Permission granted, now send notification
            self.deliverNotification(cli: cli, title: title, subtitle: subtitle, body: body, completion: completion)
        }
    }

    private func deliverNotification(
        cli: CLISource,
        title: String,
        subtitle: String,
        body: String,
        completion: @escaping (Bool) -> Void
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default

        // Add icon as attachment if available
        // UNNotificationAttachment moves the file, so we need to copy to temp first
        if let iconURL = getIconURL(for: cli) {
            let tempDir = FileManager.default.temporaryDirectory
            let tempIconURL = tempDir.appendingPathComponent("ai-notifier-\(UUID().uuidString).png")

            do {
                try FileManager.default.copyItem(at: iconURL, to: tempIconURL)
                let attachment = try UNNotificationAttachment(
                    identifier: "icon",
                    url: tempIconURL,
                    options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
                )
                content.attachments = [attachment]
            } catch {
                // Icon attachment failed, continue without icon
                fputs("Icon attachment warning: \(error.localizedDescription)\n", stderr)
            }
        }

        let identifier = "ai-notifier-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        center.add(request) { error in
            if let error = error {
                fputs("Notification error: \(error.localizedDescription)\n", stderr)
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    private func getIconURL(for cli: CLISource) -> URL? {
        // Get the app bundle's Resources directory
        let bundle = Bundle.main

        // Try to find the icon in Resources
        if let iconPath = bundle.path(forResource: cli.iconName, ofType: "png") {
            return URL(fileURLWithPath: iconPath)
        }

        // Fallback: check in the executable's directory
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let resourcesURL = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(cli.iconName).png")

        if FileManager.default.fileExists(atPath: resourcesURL.path) {
            return resourcesURL
        }

        return nil
    }
}

// MARK: - Setup Mode (Request Permission with GUI Dialog)

func runSetupMode() {
    // Activate as GUI app to show permission dialog
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.activate(ignoringOtherApps: true)

    let center = UNUserNotificationCenter.current()

    // Check current authorization status first
    let semaphore = DispatchSemaphore(value: 0)
    var currentStatus: UNAuthorizationStatus = .notDetermined

    center.getNotificationSettings { settings in
        currentStatus = settings.authorizationStatus
        semaphore.signal()
    }
    semaphore.wait()

    if currentStatus == .authorized {
        // Already authorized - show success message
        let alert = NSAlert()
        alert.messageText = "AI Notifier"
        alert.informativeText = "✅ 알림이 이미 활성화되어 있습니다!\n\nClaude Code, Gemini CLI, Codex CLI에서 알림을 받을 수 있습니다."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "확인")
        alert.runModal()
        exit(0)
    }

    // Request authorization - this will show system dialog
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "AI Notifier"

            if granted {
                alert.informativeText = "✅ 알림이 활성화되었습니다!\n\nClaude Code, Gemini CLI, Codex CLI에서 알림을 받을 수 있습니다."
                alert.alertStyle = .informational
            } else {
                alert.informativeText = "⚠️ 알림 권한이 필요합니다.\n\n시스템 설정 → 알림 → AI Notifier에서 '알림 허용'을 켜주세요."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "설정 열기")
                alert.addButton(withTitle: "닫기")

                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                }
                exit(1)
            }

            alert.addButton(withTitle: "확인")
            alert.runModal()
            exit(0)
        }
    }

    // Run the app loop briefly to show dialogs
    app.run()
}

// MARK: - Main Entry Point

func main() {
    // Check for setup mode
    if CommandLine.arguments.contains("--setup") || CommandLine.arguments.contains("-s") {
        runSetupMode()
        return
    }

    // Read stdin (hook data from CLI)
    var inputData: [String: Any]? = nil

    // Check if there's data on stdin
    if let inputString = readLine(strippingNewline: false) {
        var fullInput = inputString
        while let line = readLine(strippingNewline: false) {
            fullInput += line
        }

        if let data = fullInput.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            inputData = json
        }
    }

    // Detect CLI source
    let cli = HookDataParser.detectCLI(from: inputData)

    // Parse event
    let event = HookDataParser.parseEvent(from: inputData, cli: cli)

    // Get project name
    let projectName = ProjectInfo.getProjectName()

    // Prepare notification content
    var title = cli.displayName
    let subtitle = projectName
    var body = ""
    var shouldNotify = true

    switch event {
    case .stop(let transcript):
        body = transcript ?? "Response complete"

    case .notification(let type, let message):
        if type == "permission_prompt" {
            body = message ?? "Permission requested"
            title = "\(cli.displayName)"
        } else if type == "approval" {
            body = message ?? "Approval requested"
            title = "\(cli.displayName)"
        } else {
            body = message ?? "Notification"
        }

    case .agentTurn(let response):
        body = response ?? "Response complete"

    case .afterModel(let text):
        body = text ?? "Response complete"

    case .unknown:
        shouldNotify = false
    }

    guard shouldNotify else {
        exit(0)
    }

    // Send notification
    let semaphore = DispatchSemaphore(value: 0)
    var success = false

    NotificationManager.shared.sendNotification(
        cli: cli,
        title: title,
        subtitle: subtitle,
        body: body
    ) { result in
        success = result
        semaphore.signal()
    }

    // Wait with timeout
    let timeout = semaphore.wait(timeout: .now() + 3.0)

    if timeout == .timedOut {
        // Timeout is OK - notification might still appear
        exit(0)
    }

    exit(success ? 0 : 1)
}

// Run main
main()
