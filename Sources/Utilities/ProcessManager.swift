import Foundation
import AppKit

// MARK: - Process Manager

/// Manages single instance of ai-notifier using PID file
struct ProcessManager {
    static let pidFile = "/tmp/.ai-notifier.pid"

    /// Check if another instance is already running
    static func isAnotherInstanceRunning() -> Bool {
        guard FileManager.default.fileExists(atPath: pidFile),
              let pidString = try? String(contentsOfFile: pidFile, encoding: .utf8),
              let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }

        // Check if process with this PID is still running
        // kill(pid, 0) returns 0 if process exists, -1 if not
        let processExists = kill(pid, 0) == 0

        if processExists {
            debugLog("Another instance is running with PID: \(pid)")
            return true
        } else {
            // Stale PID file, remove it
            debugLog("Stale PID file found, removing")
            try? FileManager.default.removeItem(atPath: pidFile)
            return false
        }
    }

    /// Write current PID to file
    static func writePIDFile() {
        let pid = ProcessInfo.processInfo.processIdentifier
        try? String(pid).write(toFile: pidFile, atomically: true, encoding: .utf8)
        debugLog("Written PID file: \(pid)")
    }

    /// Remove PID file on exit
    static func removePIDFile() {
        try? FileManager.default.removeItem(atPath: pidFile)
        debugLog("Removed PID file")
    }

    /// Setup cleanup on app termination
    static func setupCleanup() {
        // Register for termination notification
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            removePIDFile()
        }

        // Also handle SIGTERM and SIGINT
        signal(SIGTERM) { _ in
            ProcessManager.removePIDFile()
            exit(0)
        }
        signal(SIGINT) { _ in
            ProcessManager.removePIDFile()
            exit(0)
        }
    }
}
