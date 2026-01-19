import Foundation

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
