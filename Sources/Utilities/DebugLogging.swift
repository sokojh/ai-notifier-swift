import Foundation

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
