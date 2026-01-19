import Foundation

// MARK: - Project Info

struct ProjectInfo {
    static func getProjectName(from data: [String: Any]? = nil) -> String {
        // Try cwd from hook data
        if let cwd = data?["cwd"] as? String {
            return URL(fileURLWithPath: cwd).lastPathComponent
        }

        // Try CLAUDE_PROJECT_ROOT
        if let projectRoot = ProcessInfo.processInfo.environment["CLAUDE_PROJECT_ROOT"] {
            return URL(fileURLWithPath: projectRoot).lastPathComponent
        }

        // Try PWD
        if let pwd = ProcessInfo.processInfo.environment["PWD"] {
            return URL(fileURLWithPath: pwd).lastPathComponent
        }

        // Fallback
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent
    }
}
