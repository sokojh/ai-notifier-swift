import Foundation
import AppKit

// MARK: - GitHub Release Model

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let assets: [Asset]

    struct Asset: Codable {
        let name: String
        let browserDownloadUrl: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

// MARK: - Update Error

enum UpdateError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case noRelease

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .noRelease:
            return "No release found"
        }
    }
}

// MARK: - Update Manager

class UpdateManager {
    static let shared = UpdateManager()

    // GitHub repository info
    let owner = "sokojh"
    let repo = "ai-notifier-swift"

    // Current version from Info.plist
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // Latest release info (cached)
    private(set) var latestRelease: GitHubRelease?

    // Check if update is available
    var updateAvailable: Bool {
        guard let release = latestRelease else { return false }
        return isNewerVersion(release.tagName, than: currentVersion)
    }

    private init() {}

    // MARK: - Check for Updates

    func checkForUpdates(completion: @escaping (Result<GitHubRelease?, Error>) -> Void) {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"

        guard let url = URL(string: urlString) else {
            completion(.failure(UpdateError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("ai-notifier/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        debugLog("UpdateManager: Checking for updates at \(urlString)")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                debugLog("UpdateManager: Network error - \(error.localizedDescription)")
                completion(.failure(UpdateError.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                debugLog("UpdateManager: Invalid response type")
                completion(.failure(UpdateError.invalidResponse))
                return
            }

            debugLog("UpdateManager: Response status code: \(httpResponse.statusCode)")

            // 404 means no releases yet
            if httpResponse.statusCode == 404 {
                debugLog("UpdateManager: No releases found (404)")
                completion(.success(nil))
                return
            }

            guard httpResponse.statusCode == 200 else {
                debugLog("UpdateManager: Unexpected status code: \(httpResponse.statusCode)")
                completion(.failure(UpdateError.invalidResponse))
                return
            }

            guard let data = data else {
                debugLog("UpdateManager: No data received")
                completion(.failure(UpdateError.invalidResponse))
                return
            }

            do {
                let decoder = JSONDecoder()
                let release = try decoder.decode(GitHubRelease.self, from: data)

                self?.latestRelease = release
                debugLog("UpdateManager: Latest release: \(release.tagName)")

                if let self = self, self.isNewerVersion(release.tagName, than: self.currentVersion) {
                    debugLog("UpdateManager: Update available! \(self.currentVersion) -> \(release.tagName)")
                    completion(.success(release))
                } else {
                    debugLog("UpdateManager: Already up to date")
                    completion(.success(nil))
                }
            } catch {
                debugLog("UpdateManager: JSON decode error - \(error.localizedDescription)")
                completion(.failure(UpdateError.invalidResponse))
            }
        }

        task.resume()
    }

    // MARK: - Open Download Page

    func openDownloadPage() {
        guard let release = latestRelease else {
            // Open releases page if no specific release
            if let url = URL(string: "https://github.com/\(owner)/\(repo)/releases") {
                NSWorkspace.shared.open(url)
            }
            return
        }

        if let url = URL(string: release.htmlUrl) {
            debugLog("UpdateManager: Opening download page: \(release.htmlUrl)")
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Version Comparison

    /// Compare two semantic versions
    /// Returns true if `new` is newer than `current`
    func isNewerVersion(_ new: String, than current: String) -> Bool {
        // Remove "v" prefix if present
        let newClean = new.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let currentClean = current.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

        let newParts = newClean.split(separator: ".").compactMap { Int($0) }
        let currentParts = currentClean.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(newParts.count, currentParts.count)

        for i in 0..<maxCount {
            let newPart = i < newParts.count ? newParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0

            if newPart > currentPart { return true }
            if newPart < currentPart { return false }
        }

        return false
    }
}
