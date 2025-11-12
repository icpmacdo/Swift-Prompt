import Foundation
import Combine

/// A singleton class that collects log messages with automatic size management.
class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published var logs: String = ""

    // Maximum number of characters to keep in logs (500KB)
    private let maxLogSize: Int = 500_000

    // Maximum number of log lines to keep
    private let maxLogLines: Int = 5_000

    /// Appends a new log message, automatically managing size limits
    func append(_ message: String) {
        DispatchQueue.main.async {
            self.logs.append(message + "\n")
            self.trimLogsIfNeeded()
        }
    }

    /// Clears all logs
    func clear() {
        DispatchQueue.main.async {
            self.logs = ""
        }
    }

    /// Trims logs if they exceed size or line limits
    private func trimLogsIfNeeded() {
        // Check character limit
        if logs.count > maxLogSize {
            // Keep only the most recent 75% of the max size
            let targetSize = (maxLogSize * 3) / 4
            let excessChars = logs.count - targetSize
            logs = String(logs.dropFirst(excessChars))

            // Clean up to start from a complete line
            if let firstNewline = logs.firstIndex(of: "\n") {
                logs = String(logs[logs.index(after: firstNewline)...])
            }

            logs = "[... earlier logs trimmed ...]\n" + logs
        }

        // Check line limit
        let lines = logs.components(separatedBy: "\n")
        if lines.count > maxLogLines {
            // Keep only the most recent 75% of max lines
            let targetLines = (maxLogLines * 3) / 4
            let recentLines = lines.suffix(targetLines)
            logs = "[... earlier logs trimmed ...]\n" + recentLines.joined(separator: "\n")
        }
    }

    /// Returns the current log size in bytes
    var logSize: Int {
        logs.count
    }

    /// Returns the current number of log lines
    var logLineCount: Int {
        logs.components(separatedBy: "\n").count
    }
}

func SwiftLog(_ message: String) {
    print(message)
    LogManager.shared.append(message)
}
