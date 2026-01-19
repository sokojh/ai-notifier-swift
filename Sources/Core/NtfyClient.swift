import Foundation

// MARK: - Ntfy Error Types

enum NtfyError: Error, LocalizedError {
    case invalidURL
    case timeout
    case networkError(String)
    case invalidResponse
    case unauthorized
    case topicNotFound
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 서버 URL입니다."
        case .timeout:
            return "서버 연결 시간이 초과되었습니다."
        case .networkError(let message):
            return "네트워크 오류: \(message)"
        case .invalidResponse:
            return "서버 응답을 처리할 수 없습니다."
        case .unauthorized:
            return "인증이 필요한 토픽입니다."
        case .topicNotFound:
            return "토픽을 찾을 수 없습니다."
        case .serverError(let code):
            return "서버 오류 (\(code))"
        }
    }
}

// MARK: - Ntfy Client (Optional Push Notification)

struct NtfyClient {
    /// Map CLI to emoji tag for ntfy
    private static func getEmojiTag(for cli: CLISource) -> String {
        switch cli {
        case .claude: return "robot"
        case .gemini: return "sparkles"
        case .codex: return "computer"
        case .opencode: return "zap"
        case .unknown: return "bell"
        }
    }

    /// Map priority string to ntfy numeric priority (1-5)
    private static func mapPriority(_ priority: String) -> String {
        switch priority.lowercased() {
        case "min", "minimum": return "1"
        case "low": return "2"
        case "default", "normal": return "3"
        case "high": return "4"
        case "max", "urgent": return "5"
        default: return "3"
        }
    }

    /// Send notification to ntfy server
    static func send(content: NotificationContent, completion: @escaping (Bool) -> Void) {
        let config = NtfyConfig.shared

        guard config.enabled else {
            completion(true)  // Skip but treat as success
            return
        }

        let urlString = "\(config.server)/\(config.topic)"
        guard let url = URL(string: urlString) else {
            debugLog("ntfy: Invalid URL - \(urlString)")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")

        // Title: include subtitle for full context (e.g., "Claude - project - 응답 완료")
        let fullTitle = "\(content.title) - \(content.subtitle)"
        request.setValue(fullTitle, forHTTPHeaderField: "Title")

        // Tags: CLI-specific emoji
        let emojiTag = getEmojiTag(for: content.cli)
        request.setValue(emojiTag, forHTTPHeaderField: "Tags")

        // Priority: map string to numeric (1-5)
        let numericPriority = mapPriority(config.priority)
        request.setValue(numericPriority, forHTTPHeaderField: "Priority")

        // Authentication (optional)
        if let auth = config.settings.auth {
            if auth.type == "bearer", let token = auth.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else if auth.type == "basic", let username = auth.username, let password = auth.password {
                let credentials = "\(username):\(password)"
                if let data = credentials.data(using: .utf8) {
                    let base64 = data.base64EncodedString()
                    request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
                }
            }
        }

        // Body
        request.httpBody = content.body.data(using: .utf8)

        // Click action - open terminal (macOS only, uses URL scheme)
        let clickURL = buildClickURL(for: content.terminalInfo)
        if let clickURL = clickURL {
            request.setValue(clickURL, forHTTPHeaderField: "Click")
        }

        debugLog("ntfy: Sending to \(urlString)")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                debugLog("ntfy: Error - \(error.localizedDescription)")
                completion(false)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                let success = (200...299).contains(httpResponse.statusCode)
                debugLog("ntfy: Response \(httpResponse.statusCode)")
                completion(success)
            } else {
                completion(false)
            }
        }

        task.resume()
    }

    /// Test connection to ntfy server (send a test notification)
    static func testConnection(
        server: String,
        topic: String,
        completion: @escaping (Result<Void, NtfyError>) -> Void
    ) {
        let urlString = "\(server)/\(topic)"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("AI Notifier 테스트", forHTTPHeaderField: "Title")
        request.setValue("white_check_mark", forHTTPHeaderField: "Tags")
        request.setValue("3", forHTTPHeaderField: "Priority")
        request.httpBody = "ntfy 연결 테스트 성공! 🎉".data(using: .utf8)
        request.timeoutInterval = 10

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.code == NSURLErrorTimedOut {
                    completion(.failure(.timeout))
                } else {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            switch httpResponse.statusCode {
            case 200...299:
                completion(.success(()))
            case 401, 403:
                completion(.failure(.unauthorized))
            case 404:
                completion(.failure(.topicNotFound))
            default:
                completion(.failure(.serverError(httpResponse.statusCode)))
            }
        }

        task.resume()
    }

    private static func buildClickURL(for terminalInfo: TerminalInfo) -> String? {
        var components = URLComponents()
        components.scheme = "ai-notifier"
        components.host = "activate"

        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "type", value: terminalInfo.type.rawValue))

        if let sessionId = terminalInfo.sessionId {
            queryItems.append(URLQueryItem(name: "sessionId", value: sessionId))
        }
        if let cwd = terminalInfo.cwd {
            queryItems.append(URLQueryItem(name: "cwd", value: cwd))
        }
        if let tty = terminalInfo.tty {
            queryItems.append(URLQueryItem(name: "tty", value: tty))
        }

        components.queryItems = queryItems
        return components.string
    }
}
