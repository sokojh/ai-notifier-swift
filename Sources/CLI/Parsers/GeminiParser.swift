import Foundation

// MARK: - Gemini Parser

struct GeminiParser {
    static func parse(data: [String: Any], title: String, cli: CLISource, terminalInfo: TerminalInfo) -> NotificationContent? {
        let hookName = data["hook_event_name"] as? String ?? ""
        let notificationType = data["notification_type"] as? String ?? ""
        let message = data["message"] as? String

        // AfterModel event
        if hookName == "AfterModel" || data["llm_response"] != nil || data["modelResponse"] != nil {
            // Check debouncing
            if !GeminiDebouncer.shouldNotify(data: data) {
                return nil  // Skip - debounced
            }

            let response = extractResponse(from: data)
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
        let response = extractResponse(from: data)
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

    private static func extractResponse(from data: [String: Any]) -> String {
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
}
