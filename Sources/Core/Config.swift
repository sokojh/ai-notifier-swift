import Foundation

// MARK: - Configuration

struct Config {
    static let previewMaxChars = 120
    static let previewMaxLines = 2
    static let debounceMs = 2000  // 2 seconds
    static let debounceDir = "/tmp"
    static let configDir = "\(NSHomeDirectory())/.config/ai-notifier"
    static let configFile = "\(configDir)/config.json"
}
