import Foundation

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

    // MARK: - Codex CLI Hook Installation (TOML format)
    // Note: notify must be at ROOT level, not inside [notice] section!

    static func installCodexHook() -> InstallResult {
        let configPath = NSString(string: "~/.codex/config.toml").expandingTildeInPath
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

        // Read existing config.toml or create empty
        var content = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""

        // Check if ai-notifier already configured (at root level)
        if content.contains("ai-notifier") {
            return .alreadyInstalled
        }

        // Add notify at ROOT level (before first section or at end if no sections)
        let notifyLine = "notify = [\"\(notifierPath)\"]"
        var lines = content.components(separatedBy: "\n")

        // Find first section header [...]
        var firstSectionIndex: Int? = nil
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                firstSectionIndex = index
                break
            }
        }

        if let idx = firstSectionIndex {
            // Insert notify before first section
            lines.insert(notifyLine, at: idx)
            lines.insert("", at: idx + 1)  // blank line after
        } else {
            // No sections, append to end
            lines.append(notifyLine)
        }

        content = lines.joined(separator: "\n")

        // Write config
        do {
            try content.write(toFile: configPath, atomically: true, encoding: .utf8)
            return .installed
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // MARK: - OpenCode CLI Hook Installation (Plugin-based)
    // Reference: https://github.com/mohak34/opencode-notifier

    static func installOpenCodeHook() -> InstallResult {
        // OpenCode uses ~/.config/opencode/plugin/ for global plugins
        let pluginDir = NSString(string: "~/.config/opencode/plugin").expandingTildeInPath
        let pluginFile = "\(pluginDir)/ai-notifier.ts"
        let openCodeConfigDir = NSString(string: "~/.config/opencode").expandingTildeInPath

        // Check if OpenCode CLI is installed
        let openCodeExists = FileManager.default.fileExists(atPath: openCodeConfigDir) ||
                            FileManager.default.fileExists(atPath: "/usr/local/bin/opencode") ||
                            FileManager.default.fileExists(atPath: "/opt/homebrew/bin/opencode")

        if !openCodeExists {
            return .notFound
        }

        // Check if plugin already exists
        if FileManager.default.fileExists(atPath: pluginFile) {
            if let content = try? String(contentsOfFile: pluginFile, encoding: .utf8),
               content.contains("ai-notifier") {
                return .alreadyInstalled
            }
        }

        // Create plugin directory if needed
        try? FileManager.default.createDirectory(atPath: pluginDir, withIntermediateDirectories: true)

        // Create plugin code following OpenCode plugin format
        // Uses @opencode-ai/plugin SDK pattern
        // Event structure: { event: { type: "session.idle", properties: {...} } }
        let pluginCode = """
        import type { Plugin } from "@opencode-ai/plugin";
        import { execSync } from "child_process";
        import { basename } from "path";

        function notify(eventType: string, projectName: string, responsePreview?: string) {
          try {
            const cwd = process.cwd();
            const data = JSON.stringify({
              hook_event_name: eventType,
              cwd: cwd,
              cli: "opencode",
              project_name: projectName || basename(cwd),
              response_preview: responsePreview || ""
            });
            execSync(`echo '${data.replace(/'/g, "'\\''")}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier`, {
              stdio: 'ignore',
              timeout: 5000
            });
          } catch (e) {
            // Ignore errors silently
          }
        }

        export const AiNotifierPlugin: Plugin = async ({ directory }) => {
          const projectName = basename(directory);
          let lastResponseText = "";

          return {
            event: async (eventData: any) => {
              const eventType = eventData?.event?.type;
              const props = eventData?.event?.properties;

              // Track assistant response text
              if (eventType === "message.part.updated") {
                const part = props?.part;
                if (part?.type === "text" && part?.text) {
                  lastResponseText = part.text.trim();
                }
              }

              if (eventType === "session.idle") {
                const preview = lastResponseText.substring(0, 200);
                notify("complete", projectName, preview);
                lastResponseText = "";
              } else if (eventType === "session.error") {
                notify("error", projectName);
                lastResponseText = "";
              }
            },

            "permission.ask": async () => {
              notify("permission", projectName);
            }
          };
        };

        export default AiNotifierPlugin;
        """

        // Write plugin file
        do {
            try pluginCode.write(toFile: pluginFile, atomically: true, encoding: .utf8)
            return .installed
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Install All Hooks

    static func installAllHooks() -> (claude: InstallResult, gemini: InstallResult, codex: InstallResult, opencode: InstallResult) {
        return (
            claude: installClaudeHook(),
            gemini: installGeminiHook(),
            codex: installCodexHook(),
            opencode: installOpenCodeHook()
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
