import Foundation

// MARK: - Ntfy Configuration Models

struct NtfyAuth: Codable {
    let type: String?      // "bearer" or "basic"
    let token: String?     // Bearer token
    let username: String?  // Basic auth username
    let password: String?  // Basic auth password
}

struct NtfySettings: Codable {
    let enabled: Bool
    let server: String
    let topic: String
    let priority: String?
    let auth: NtfyAuth?

    static let `default` = NtfySettings(
        enabled: false,
        server: "https://ntfy.sh",
        topic: "",
        priority: "default",
        auth: nil
    )
}

struct AppConfig: Codable {
    let ntfy: NtfySettings?

    static func load() -> AppConfig {
        let configPath = Config.configFile

        guard FileManager.default.fileExists(atPath: configPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig(ntfy: nil)
        }

        return config
    }
}
