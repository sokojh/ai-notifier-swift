import Foundation

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
