import Foundation

// MARK: - Ntfy Configuration Singleton

class NtfyConfig {
    static let shared = NtfyConfig()

    private(set) var settings: NtfySettings

    var enabled: Bool { settings.enabled && !settings.topic.isEmpty }
    var server: String { settings.server }
    var topic: String { settings.topic }
    var priority: String { settings.priority ?? "default" }

    private init() {
        let appConfig = AppConfig.load()
        self.settings = appConfig.ntfy ?? NtfySettings.default

        if enabled {
            debugLog("ntfy enabled: \(server)/\(topic)")
        }
    }

    func reload() {
        let appConfig = AppConfig.load()
        self.settings = appConfig.ntfy ?? NtfySettings.default
    }
}
