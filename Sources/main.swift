import Foundation
import UserNotifications
import AppKit
import Darwin

// MARK: - Configuration

struct Config {
    static let previewMaxChars = 120
    static let previewMaxLines = 2
    static let debounceMs = 2000  // 2 seconds
    static let debounceDir = "/tmp"
}

// MARK: - CLI Types

enum CLISource: String, CaseIterable {
    case claude = "claude"
    case gemini = "gemini"
    case codex = "codex"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .codex: return "Codex"
        case .unknown: return "AI"
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

// MARK: - Terminal Info (for click-to-activate)

enum TerminalType: String {
    case iterm2 = "iTerm.app"
    case vscode = "vscode"
    case terminal = "Apple_Terminal"
    case unknown = "unknown"

    static func detect() -> TerminalType {
        guard let termProgram = ProcessInfo.processInfo.environment["TERM_PROGRAM"] else {
            return .unknown
        }
        return TerminalType(rawValue: termProgram) ?? .unknown
    }
}

struct TerminalInfo {
    let type: TerminalType
    let sessionId: String?  // iTerm2 ITERM_SESSION_ID
    let cwd: String?        // Working directory for VS Code
    let tty: String?        // TTY device for Terminal.app (e.g., /dev/ttys001)

    static func capture(cwd: String? = nil) -> TerminalInfo {
        let env = ProcessInfo.processInfo.environment
        return TerminalInfo(
            type: TerminalType.detect(),
            sessionId: env["ITERM_SESSION_ID"],
            cwd: cwd ?? env["PWD"],
            tty: env["TTY"] ?? getCurrentTTY()
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
        return dict
    }

    static func from(dictionary: [String: String]) -> TerminalInfo {
        return TerminalInfo(
            type: TerminalType(rawValue: dictionary["terminalType"] ?? "") ?? .unknown,
            sessionId: dictionary["sessionId"],
            cwd: dictionary["cwd"],
            tty: dictionary["tty"]
        )
    }
}

// MARK: - Notification Content

struct NotificationContent {
    let title: String      // "Claude - project-name"
    let subtitle: String   // "응답 완료" / "권한 요청" / "입력 대기"
    let body: String       // Response preview
    let cli: CLISource
    let terminalInfo: TerminalInfo
}

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
        case .unknown:
            // Try to activate based on available info
            if info.sessionId != nil {
                activateITerm2(sessionId: info.sessionId)
            } else if info.tty != nil {
                activateTerminalApp(tty: info.tty)
            } else if let cwd = info.cwd {
                activateVSCode(cwd: cwd)
            }
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
            // Use VS Code CLI to activate the window with this folder
            // Note: "code <folder>" without -r flag will find and activate
            // the existing window that has this folder open

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
        } else {
            debugLog("No cwd provided, skipping code command")
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
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["vscode://command/workbench.action.terminal.focus"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
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

// MARK: - Text Utilities

struct TextUtils {
    /// Get preview text (max 120 chars, 2 lines)
    static func getPreviewText(_ content: String?, maxLines: Int = Config.previewMaxLines, maxChars: Int = Config.previewMaxChars) -> String {
        guard let content = content, !content.isEmpty else { return "" }

        let lines = content.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n", omittingEmptySubsequences: false)
        var previewLines: [String] = []
        var totalChars = 0

        for rawLine in lines.prefix(maxLines + 2) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if previewLines.count >= maxLines { break }

            if totalChars + line.count > maxChars {
                let remaining = maxChars - totalChars
                if remaining > 10 {
                    previewLines.append(String(line.prefix(remaining)) + "...")
                }
                break
            }

            previewLines.append(line)
            totalChars += line.count + 1
        }

        var result = previewLines.joined(separator: " ")
        if content.count > result.count && !result.hasSuffix("...") {
            result += "..."
        }

        return result
    }
}

// MARK: - Project Info

struct ProjectInfo {
    static func getProjectName(from data: [String: Any]? = nil) -> String {
        // Try cwd from hook data
        if let cwd = data?["cwd"] as? String {
            return URL(fileURLWithPath: cwd).lastPathComponent
        }

        // Try CLAUDE_PROJECT_ROOT
        if let projectRoot = ProcessInfo.processInfo.environment["CLAUDE_PROJECT_ROOT"] {
            return URL(fileURLWithPath: projectRoot).lastPathComponent
        }

        // Try PWD
        if let pwd = ProcessInfo.processInfo.environment["PWD"] {
            return URL(fileURLWithPath: pwd).lastPathComponent
        }

        // Fallback
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent
    }
}

// MARK: - Gemini Debouncing

struct GeminiDebouncer {
    /// Check if should notify for Gemini (with debouncing)
    static func shouldNotify(data: [String: Any]) -> Bool {
        // Extract finishReason from llm_response.candidates[0].finishReason
        var finishReason: String = ""

        if let llmResponse = data["llm_response"] as? [String: Any],
           let candidates = llmResponse["candidates"] as? [[String: Any]],
           let first = candidates.first,
           let reason = first["finishReason"] as? String {
            finishReason = reason
        } else if let reason = data["finishReason"] as? String {
            finishReason = reason
        }

        // Only notify on STOP - skip all other cases (streaming chunks)
        if finishReason != "STOP" {
            return false
        }

        // Session-based debouncing
        guard let sessionId = data["session_id"] as? String else {
            return true
        }

        let lockFile = "\(Config.debounceDir)/.gemini-notify-\(sessionId).lock"
        let now = Date().timeIntervalSince1970 * 1000  // milliseconds

        if FileManager.default.fileExists(atPath: lockFile) {
            if let content = try? String(contentsOfFile: lockFile, encoding: .utf8),
               let lastTime = Double(content.trimmingCharacters(in: .whitespacesAndNewlines)) {
                if now - lastTime < Double(Config.debounceMs) {
                    // Update timestamp but don't notify
                    try? String(Int(now)).write(toFile: lockFile, atomically: true, encoding: .utf8)
                    return false
                }
            }
        }

        // Write new timestamp
        try? String(Int(now)).write(toFile: lockFile, atomically: true, encoding: .utf8)
        return true
    }
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
            if data["llm_response"] != nil || data["modelResponse"] != nil || data["finishReason"] != nil {
                return .gemini
            }
            if data["event"] as? String == "agent-turn-complete" ||
               data["type"] as? String == "agent-turn-complete" {
                return .codex
            }

            // Check transcript_path
            if let transcriptPath = data["transcript_path"] as? String {
                if transcriptPath.contains("/.claude/") { return .claude }
                if transcriptPath.contains("/.gemini/") { return .gemini }
            }

            // Check hook_event_name for Claude/Gemini
            if data["hook_event_name"] != nil {
                let notificationType = data["notification_type"] as? String ?? ""
                if ["idle_prompt", "permission_prompt"].contains(notificationType) {
                    return .claude
                }
                if notificationType == "ToolPermission" {
                    return .gemini
                }
                if data["stop_hook_active"] != nil {
                    return .claude
                }
                if data["llm_response"] != nil {
                    return .gemini
                }
            }
        }

        // Default to claude
        return .claude
    }

    /// Parse notification content from hook data
    static func parseNotification(from data: [String: Any]?, cli: CLISource) -> NotificationContent? {
        // No data = no notification (e.g., app relaunched for notification click handling)
        guard let data = data else {
            return nil
        }

        let projectName = ProjectInfo.getProjectName(from: data)
        let title = "\(cli.displayName) - \(projectName)"

        // Capture terminal info for click-to-activate
        let cwd = data["cwd"] as? String
        let terminalInfo = TerminalInfo.capture(cwd: cwd)

        switch cli {
        case .claude:
            return parseClaudeNotification(data: data, title: title, cli: cli, terminalInfo: terminalInfo)
        case .gemini:
            return parseGeminiNotification(data: data, title: title, cli: cli, terminalInfo: terminalInfo)
        case .codex:
            return parseCodexNotification(data: data, title: title, cli: cli, terminalInfo: terminalInfo)
        case .unknown:
            return NotificationContent(
                title: title,
                subtitle: "알림",
                body: "상태가 변경되었습니다",
                cli: cli,
                terminalInfo: terminalInfo
            )
        }
    }

    // MARK: - Claude Parsing

    private static func parseClaudeNotification(data: [String: Any], title: String, cli: CLISource, terminalInfo: TerminalInfo) -> NotificationContent? {
        let hookName = data["hook_event_name"] as? String ?? data["hook_name"] as? String ?? ""
        let notificationType = data["notification_type"] as? String ?? ""
        let message = data["message"] as? String

        // Stop event
        if hookName == "Stop" || data["stop_hook_active"] as? Bool == true {
            let response = extractClaudeResponse(from: data)
            return NotificationContent(
                title: title,
                subtitle: "응답 완료",
                body: response.isEmpty ? "응답을 확인하세요" : response,
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        // Notification event
        if hookName == "Notification" {
            if notificationType == "idle_prompt" {
                return NotificationContent(
                    title: title,
                    subtitle: "입력 대기",
                    body: "사용자 입력을 기다리고 있습니다",
                    cli: cli,
                    terminalInfo: terminalInfo
                )
            }

            if notificationType == "permission_prompt" {
                return NotificationContent(
                    title: title,
                    subtitle: "권한 요청",
                    body: message ?? "권한 승인이 필요합니다",
                    cli: cli,
                    terminalInfo: terminalInfo
                )
            }

            return NotificationContent(
                title: title,
                subtitle: notificationType.isEmpty ? "알림" : notificationType,
                body: message ?? "응답을 확인하세요",
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        // Default - treat as stop
        let response = extractClaudeResponse(from: data)
        return NotificationContent(
            title: title,
            subtitle: "응답 완료",
            body: response.isEmpty ? "응답을 확인하세요" : response,
            cli: cli,
            terminalInfo: terminalInfo
        )
    }

    private static func extractClaudeResponse(from data: [String: Any]) -> String {
        // Try transcript array in JSON
        if let transcript = data["transcript"] as? [[String: Any]] {
            for item in transcript.reversed() {
                if item["type"] as? String == "assistant" {
                    if let message = item["message"] as? [String: Any],
                       let content = message["content"] as? [[String: Any]] {
                        for block in content.reversed() {
                            if block["type"] as? String == "text",
                               let text = block["text"] as? String {
                                return TextUtils.getPreviewText(text)
                            }
                        }
                    }
                }
            }
        }

        // Try transcript_path (read from file)
        if let transcriptPath = data["transcript_path"] as? String,
           FileManager.default.fileExists(atPath: transcriptPath) {
            if let content = try? String(contentsOfFile: transcriptPath, encoding: .utf8) {
                let lines = content.split(separator: "\n").reversed()
                for line in lines {
                    if let lineData = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                       json["type"] as? String == "assistant" {
                        if let message = json["message"] as? [String: Any],
                           let msgContent = message["content"] as? [[String: Any]] {
                            for block in msgContent.reversed() {
                                if block["type"] as? String == "text",
                                   let text = block["text"] as? String {
                                    return TextUtils.getPreviewText(text)
                                }
                            }
                        }
                    }
                }
            }
        }

        return ""
    }

    // MARK: - Gemini Parsing

    private static func parseGeminiNotification(data: [String: Any], title: String, cli: CLISource, terminalInfo: TerminalInfo) -> NotificationContent? {
        let hookName = data["hook_event_name"] as? String ?? ""
        let notificationType = data["notification_type"] as? String ?? ""
        let message = data["message"] as? String

        // AfterModel event
        if hookName == "AfterModel" || data["llm_response"] != nil || data["modelResponse"] != nil {
            // Check debouncing
            if !GeminiDebouncer.shouldNotify(data: data) {
                return nil  // Skip - debounced
            }

            let response = extractGeminiResponse(from: data)
            return NotificationContent(
                title: title,
                subtitle: "응답 완료",
                body: response.isEmpty ? "응답을 확인하세요" : response,
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        // Notification event
        if hookName == "Notification" {
            if notificationType == "ToolPermission" {
                return NotificationContent(
                    title: title,
                    subtitle: "권한 요청",
                    body: message ?? "권한 승인이 필요합니다",
                    cli: cli,
                    terminalInfo: terminalInfo
                )
            }

            return NotificationContent(
                title: title,
                subtitle: notificationType.isEmpty ? "알림" : notificationType,
                body: message ?? "응답을 확인하세요",
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        // Default
        let response = extractGeminiResponse(from: data)
        if response.isEmpty && hookName.isEmpty {
            return nil  // No meaningful content
        }

        return NotificationContent(
            title: title,
            subtitle: "응답 완료",
            body: response.isEmpty ? "응답을 확인하세요" : response,
            cli: cli,
            terminalInfo: terminalInfo
        )
    }

    /// Check if two ISO8601 timestamps are close (within tolerance seconds)
    private static func isTimestampClose(_ ts1: String, _ ts2: String, toleranceSeconds: Double) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try parsing with fractional seconds first, then without
        func parseDate(_ str: String) -> Date? {
            if let date = formatter.date(from: str) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: str)
        }

        guard let date1 = parseDate(ts1), let date2 = parseDate(ts2) else {
            return true  // If can't parse, assume they're close
        }

        return abs(date1.timeIntervalSince(date2)) <= toleranceSeconds
    }

    private static func extractGeminiResponse(from data: [String: Any]) -> String {
        // NOTE: Don't use transcript_path - it has timing issues where old responses are returned
        // Instead, only use llm_response from the event itself

        // Try llm_response (from the current event)
        if let llmResponse = data["llm_response"] as? [String: Any] {
            // 1. Direct text field
            if let text = llmResponse["text"] as? String, !text.isEmpty {
                return TextUtils.getPreviewText(text)
            }

            // 2. Try candidates array
            if let candidates = llmResponse["candidates"] as? [[String: Any]] {
                for candidate in candidates {
                    if let content = candidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]] {
                        for part in parts {
                            if let text = part["text"] as? String, !text.isEmpty {
                                return TextUtils.getPreviewText(text)
                            }
                        }
                    }
                }
            }
        }

        // PRIORITY 3: Try modelResponse
        if let modelResponse = data["modelResponse"] as? [String: Any] {
            if let candidates = modelResponse["candidates"] as? [[String: Any]] {
                for candidate in candidates {
                    if let content = candidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]] {
                        for part in parts {
                            if let text = part["text"] as? String, !text.isEmpty {
                                return TextUtils.getPreviewText(text)
                            }
                        }
                    }
                }
            }
        }

        return ""
    }

    // MARK: - Codex Parsing

    private static func parseCodexNotification(data: [String: Any], title: String, cli: CLISource, terminalInfo: TerminalInfo) -> NotificationContent? {
        let eventType = data["type"] as? String ?? data["event"] as? String ?? data["event_type"] as? String ?? ""

        if eventType == "agent-turn-complete" {
            let response = extractCodexResponse(from: data)
            return NotificationContent(
                title: title,
                subtitle: "응답 완료",
                body: response.isEmpty ? "응답을 확인하세요" : response,
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        if eventType == "approval-requested" {
            let message = data["message"] as? String
            return NotificationContent(
                title: title,
                subtitle: "권한 요청",
                body: message ?? "권한 승인이 필요합니다",
                cli: cli,
                terminalInfo: terminalInfo
            )
        }

        // Default
        let response = extractCodexResponse(from: data)
        return NotificationContent(
            title: title,
            subtitle: eventType.isEmpty ? "알림" : eventType,
            body: response.isEmpty ? "상태가 변경되었습니다" : response,
            cli: cli,
            terminalInfo: terminalInfo
        )
    }

    private static func extractCodexResponse(from data: [String: Any]) -> String {
        if let message = data["last-assistant-message"] as? String {
            return TextUtils.getPreviewText(message)
        }
        if let message = data["message"] as? String {
            return TextUtils.getPreviewText(message)
        }
        if let response = data["response"] as? String {
            return TextUtils.getPreviewText(response)
        }
        return ""
    }
}

// MARK: - Notification Manager

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    var didHandleNotificationClick = false

    override init() {
        super.init()
        center.delegate = self
    }

    func sendNotification(
        content: NotificationContent,
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
            self.deliverNotification(content: content, completion: completion)
        }
    }

    private func deliverNotification(
        content: NotificationContent,
        completion: @escaping (Bool) -> Void
    ) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = content.title
        notificationContent.subtitle = content.subtitle
        notificationContent.body = content.body
        notificationContent.sound = .default

        // Store terminal info in userInfo for click handling
        notificationContent.userInfo = content.terminalInfo.toDictionary()

        // Add icon as attachment if available
        if let iconURL = getIconURL(for: content.cli) {
            let tempDir = FileManager.default.temporaryDirectory
            let tempIconURL = tempDir.appendingPathComponent("ai-notifier-\(UUID().uuidString).png")

            do {
                try FileManager.default.copyItem(at: iconURL, to: tempIconURL)
                let attachment = try UNNotificationAttachment(
                    identifier: "icon",
                    url: tempIconURL,
                    options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
                )
                notificationContent.attachments = [attachment]
            } catch {
                // Icon attachment failed, continue without icon
            }
        }

        let identifier = "ai-notifier-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: notificationContent, trigger: nil)

        center.add(request) { error in
            if let error = error {
                fputs("Notification error: \(error.localizedDescription)\n", stderr)
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        debugLog("Notification clicked! Action: \(response.actionIdentifier)")
        didHandleNotificationClick = true

        // Handle notification click
        let userInfo = response.notification.request.content.userInfo
        debugLog("UserInfo: \(userInfo)")

        // Extract terminal info from userInfo (handle [AnyHashable: Any] type)
        var terminalDict: [String: String] = [:]
        for (key, value) in userInfo {
            if let keyStr = key as? String, let valueStr = value as? String {
                terminalDict[keyStr] = valueStr
            }
        }

        if !terminalDict.isEmpty {
            let terminalInfo = TerminalInfo.from(dictionary: terminalDict)
            debugLog("Terminal info: type=\(terminalInfo.type), sessionId=\(terminalInfo.sessionId ?? "nil"), tty=\(terminalInfo.tty ?? "nil"), cwd=\(terminalInfo.cwd ?? "nil")")
            TerminalActivator.activate(terminalInfo)
        } else {
            debugLog("No terminal info in userInfo")
        }

        completionHandler()

        // Exit after handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    private func getIconURL(for cli: CLISource) -> URL? {
        let bundle = Bundle.main

        if let iconPath = bundle.path(forResource: cli.iconName, ofType: "png") {
            return URL(fileURLWithPath: iconPath)
        }

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

// MARK: - CLI Hook Installer

struct CLIHookInstaller {
    static let notifierPath = "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"

    enum InstallResult {
        case installed
        case alreadyInstalled
        case notFound
        case error(String)
    }

    // MARK: - Claude Code Hook Installation

    static func installClaudeHook() -> InstallResult {
        let settingsPath = NSString(string: "~/.claude/settings.json").expandingTildeInPath
        let claudeDir = NSString(string: "~/.claude").expandingTildeInPath

        // Check if Claude Code is installed (settings dir exists or claude command exists)
        let claudeExists = FileManager.default.fileExists(atPath: claudeDir) ||
                          FileManager.default.fileExists(atPath: "/usr/local/bin/claude") ||
                          FileManager.default.fileExists(atPath: "/opt/homebrew/bin/claude")

        if !claudeExists {
            return .notFound
        }

        // Create directory if needed
        try? FileManager.default.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)

        // Read existing settings or create new
        var settings: [String: Any] = [:]
        if let data = FileManager.default.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        // Check if hooks already configured
        if let hooks = settings["hooks"] as? [String: Any],
           let stopHooks = hooks["Stop"] as? [[String: Any]] {
            for hook in stopHooks {
                if let hooksList = hook["hooks"] as? [[String: Any]] {
                    for h in hooksList {
                        if let cmd = h["command"] as? String, cmd.contains("ai-notifier") {
                            return .alreadyInstalled
                        }
                    }
                }
            }
        }

        // Create hook configuration
        let hookConfig: [String: Any] = [
            "matcher": "",
            "hooks": [
                ["type": "command", "command": notifierPath]
            ]
        ]

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        // Add Stop hook
        var stopHooks = hooks["Stop"] as? [[String: Any]] ?? []
        stopHooks.append(hookConfig)
        hooks["Stop"] = stopHooks

        // Add Notification hook
        var notificationHooks = hooks["Notification"] as? [[String: Any]] ?? []
        notificationHooks.append(hookConfig)
        hooks["Notification"] = notificationHooks

        settings["hooks"] = hooks

        // Write settings
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: settingsPath))
            return .installed
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Gemini CLI Hook Installation

    static func installGeminiHook() -> InstallResult {
        let settingsPath = NSString(string: "~/.gemini/settings.json").expandingTildeInPath
        let geminiDir = NSString(string: "~/.gemini").expandingTildeInPath

        // Check if Gemini CLI is installed
        let geminiExists = FileManager.default.fileExists(atPath: geminiDir) ||
                          FileManager.default.fileExists(atPath: "/usr/local/bin/gemini") ||
                          FileManager.default.fileExists(atPath: "/opt/homebrew/bin/gemini")

        if !geminiExists {
            return .notFound
        }

        // Create directory if needed
        try? FileManager.default.createDirectory(atPath: geminiDir, withIntermediateDirectories: true)

        // Read existing settings or create new
        var settings: [String: Any] = [:]
        if let data = FileManager.default.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        // Check if hooks already configured (can be string or array format)
        if let hooks = settings["hooks"] as? [String: Any] {
            // Check string format
            if let afterModel = hooks["AfterModel"] as? String, afterModel.contains("ai-notifier") {
                return .alreadyInstalled
            }
            // Check array format
            if let afterModelArray = hooks["AfterModel"] as? [[String: Any]] {
                for item in afterModelArray {
                    if let hooksList = item["hooks"] as? [[String: Any]] {
                        for h in hooksList {
                            if let cmd = h["command"] as? String, cmd.contains("ai-notifier") {
                                return .alreadyInstalled
                            }
                        }
                    }
                }
            }
        }

        // Create hook configuration (array format - compatible with Gemini CLI)
        let hookConfig: [String: Any] = [
            "hooks": [
                [
                    "name": "ai-notifier",
                    "type": "command",
                    "command": notifierPath,
                    "timeout": 5000
                ]
            ]
        ]

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        hooks["enabled"] = true

        // Add AfterModel hook
        var afterModelHooks = hooks["AfterModel"] as? [[String: Any]] ?? []
        afterModelHooks.append(hookConfig)
        hooks["AfterModel"] = afterModelHooks

        // Add Notification hook (for permission prompts)
        var notificationHooks = hooks["Notification"] as? [[String: Any]] ?? []
        notificationHooks.append(hookConfig)
        hooks["Notification"] = notificationHooks

        settings["hooks"] = hooks

        // Write settings
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: settingsPath))
            return .installed
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Codex CLI Hook Installation

    static func installCodexHook() -> InstallResult {
        let settingsPath = NSString(string: "~/.codex/config.json").expandingTildeInPath
        let codexDir = NSString(string: "~/.codex").expandingTildeInPath

        // Check if Codex CLI is installed
        let codexExists = FileManager.default.fileExists(atPath: codexDir) ||
                         FileManager.default.fileExists(atPath: "/usr/local/bin/codex") ||
                         FileManager.default.fileExists(atPath: "/opt/homebrew/bin/codex")

        if !codexExists {
            return .notFound
        }

        // Create directory if needed
        try? FileManager.default.createDirectory(atPath: codexDir, withIntermediateDirectories: true)

        // Read existing settings or create new
        var settings: [String: Any] = [:]
        if let data = FileManager.default.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        // Check if hooks already configured
        if let hooks = settings["hooks"] as? [String: Any] {
            if let onComplete = hooks["agent-turn-complete"] as? String, onComplete.contains("ai-notifier") {
                return .alreadyInstalled
            }
        }

        // Add hooks
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        hooks["agent-turn-complete"] = notifierPath
        hooks["approval-requested"] = notifierPath
        settings["hooks"] = hooks

        // Write settings
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: settingsPath))
            return .installed
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Install All Hooks

    static func installAllHooks() -> (claude: InstallResult, gemini: InstallResult, codex: InstallResult) {
        return (
            claude: installClaudeHook(),
            gemini: installGeminiHook(),
            codex: installCodexHook()
        )
    }

    static func resultToString(_ result: InstallResult, cliName: String) -> String {
        switch result {
        case .installed:
            return "\(cliName): 훅 설치 완료"
        case .alreadyInstalled:
            return "\(cliName): 이미 설정됨"
        case .notFound:
            return "\(cliName): 미설치 (건너뜀)"
        case .error(let msg):
            return "\(cliName): 오류 - \(msg)"
        }
    }
}

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

    // Count installed
    let installedCount = [results.claude, results.gemini, results.codex].filter {
        if case .installed = $0 { return true }
        if case .alreadyInstalled = $0 { return true }
        return false
    }.count

    let alert = NSAlert()
    alert.messageText = "AI Notifier 설정 완료"

    if installedCount > 0 {
        alert.informativeText = "알림 권한: 활성화됨\n\nCLI 훅 설정:\n• \(messages.joined(separator: "\n• "))\n\n이제 CLI 응답 완료 시 알림을 받을 수 있습니다!"
        alert.alertStyle = .informational
    } else {
        alert.informativeText = "알림 권한: 활성화됨\n\nCLI 훅 설정:\n• \(messages.joined(separator: "\n• "))\n\n설치된 CLI가 없습니다. Claude Code, Gemini CLI, 또는 Codex CLI를 설치한 후 다시 실행해주세요."
        alert.alertStyle = .warning
    }

    alert.addButton(withTitle: "확인")
    alert.runModal()
    exit(0)
}

// MARK: - Debug Logging

func debugLog(_ message: String) {
    let logFile = "/tmp/ai-notifier-debug.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logMessage = "[\(timestamp)] \(message)\n"

    if let handle = FileHandle(forWritingAtPath: logFile) {
        handle.seekToEndOfFile()
        handle.write(logMessage.data(using: .utf8)!)
        handle.closeFile()
    } else {
        try? logMessage.write(toFile: logFile, atomically: true, encoding: .utf8)
    }
}

// MARK: - URL Scheme Handler

func handleURLScheme(_ urlString: String) {
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
        tty: params["tty"]
    )

    debugLog("Activating terminal: \(terminalInfo.type)")
    TerminalActivator.activate(terminalInfo)
}

// MARK: - Main Entry Point

func main() {
    // Check for setup mode
    if CommandLine.arguments.contains("--setup") || CommandLine.arguments.contains("-s") {
        runSetupMode()
        return
    }

    // Check for URL scheme activation (ai-notifier://activate?...)
    if CommandLine.arguments.count > 1 {
        let arg = CommandLine.arguments[1]
        if arg.hasPrefix("ai-notifier://") {
            debugLog("=== URL scheme activation ===")
            handleURLScheme(arg)
            exit(0)
        }
    }

    debugLog("=== ai-notifier started ===")
    debugLog("Arguments count: \(CommandLine.arguments.count)")
    debugLog("Arguments: \(CommandLine.arguments)")

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

    // Detect CLI source
    let cli = HookDataParser.detectCLI(from: inputData)
    debugLog("Detected CLI: \(cli.rawValue)")

    // Parse notification content
    guard let content = HookDataParser.parseNotification(from: inputData, cli: cli) else {
        // parseNotification returned nil - could be:
        // 1. Debounced (inputData not empty but skipped)
        // 2. Launched from notification click (inputData empty)
        // 3. Launched directly by user (double-click from Finder/DMG)

        // Check if launched directly (TTY or no stdin data)
        let isDirectLaunch = isatty(FileHandle.standardInput.fileDescriptor) != 0

        if isDirectLaunch {
            // User double-clicked the app - run setup mode
            debugLog("Direct launch detected - running setup mode")
            runSetupMode()
            return
        }

        // If we had input data but parseNotification returned nil, it was debounced - exit silently
        if inputData != nil && !(inputData?.isEmpty ?? true) {
            debugLog("Debounced - exiting silently")
            return
        }

        // Launched from notification click - wait for delegate callback
        debugLog("parseNotification returned nil (no input data) - waiting for notification click callback")

        // Initialize notification manager (sets up delegate)
        _ = NotificationManager.shared

        // Use NSApplication for better delegate handling
        debugLog("Starting NSApplication run loop...")
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        // Set timeout to exit (if no notification click after 3 seconds, run setup)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if !NotificationManager.shared.didHandleNotificationClick {
                debugLog("No notification click received - running setup mode")
                runSetupMode()
            }
        }

        app.run()
        return  // Won't reach here, but for clarity
    }

    debugLog("Notification: title=\(content.title), subtitle=\(content.subtitle), body=\(content.body.prefix(50))...")
    debugLog("TerminalInfo: type=\(content.terminalInfo.type), sessionId=\(content.terminalInfo.sessionId ?? "nil"), tty=\(content.terminalInfo.tty ?? "nil"), cwd=\(content.terminalInfo.cwd ?? "nil")")

    // Save terminal info for notification click handling
    let lastSessionFile = "/tmp/.ai-notifier-last-session.json"
    let sessionDict = content.terminalInfo.toDictionary()
    if let jsonData = try? JSONSerialization.data(withJSONObject: sessionDict),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        try? jsonString.write(toFile: lastSessionFile, atomically: true, encoding: .utf8)
        debugLog("Saved session to \(lastSessionFile)")
    }

    // Send notification
    let semaphore = DispatchSemaphore(value: 0)
    var success = false

    NotificationManager.shared.sendNotification(content: content) { result in
        success = result
        semaphore.signal()
    }

    // Wait with timeout
    let timeout = semaphore.wait(timeout: .now() + 3.0)

    if timeout == .timedOut {
        exit(0)
    }

    exit(success ? 0 : 1)
}

// Run main
main()
