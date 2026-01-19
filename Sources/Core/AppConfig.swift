import Foundation

// MARK: - Ntfy Configuration Models

struct NtfyAuth: Codable {
    let type: String?      // "bearer" or "basic"
    let token: String?     // Bearer token
    let username: String?  // Basic auth username
    let password: String?  // Basic auth password
}

struct NtfySettings: Codable {
    var enabled: Bool
    var server: String
    var topic: String
    var priority: String?
    var auth: NtfyAuth?

    static let `default` = NtfySettings(
        enabled: false,
        server: "https://ntfy.sh",
        topic: "",
        priority: "default",
        auth: nil
    )

    /// Create settings for simple setup (no auth)
    static func simple(enabled: Bool, server: String, topic: String) -> NtfySettings {
        return NtfySettings(
            enabled: enabled,
            server: server,
            topic: topic,
            priority: "default",
            auth: nil
        )
    }
}

struct AppConfig: Codable {
    var ntfy: NtfySettings?

    static func load() -> AppConfig {
        let configPath = Config.configFile

        guard FileManager.default.fileExists(atPath: configPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig(ntfy: nil)
        }

        return config
    }

    func save() throws {
        let configDir = Config.configDir
        let configPath = Config.configFile

        // Create config directory if not exists
        if !FileManager.default.fileExists(atPath: configDir) {
            try FileManager.default.createDirectory(
                atPath: configDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: URL(fileURLWithPath: configPath))

        debugLog("Config saved to \(configPath)")
    }
}
