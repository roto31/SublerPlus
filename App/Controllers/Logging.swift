import Foundation
import os.log

public enum AppLog {
    static let general = Logger(subsystem: "com.sublerplus.app", category: "general")
    static var level: LogLevel = {
        if let env = ProcessInfo.processInfo.environment["LOG_LEVEL"]?.lowercased(), env == "minimal" {
            return .minimal
        }
        return .normal
    }()

    static func log(_ message: String, level: LogLevel = .normal) {
        guard level == .normal || self.level == .normal else { return }
        general.log("\(message, privacy: .public)")
    }
}

/// Scrub API keys or bearer tokens from log strings.
func scrubSecrets(_ text: String) -> String {
    let patterns = [
        "(?i)api_key=([A-Za-z0-9._-]+)",
        "(?i)bearer\\s+[A-Za-z0-9._-]+",
        "(?i)x-api-key:\\s*[A-Za-z0-9._-]+"
    ]
    return patterns.reduce(text) { partial, pattern in
        partial.replacingOccurrences(of: pattern, with: "***", options: .regularExpression)
    }
}

public enum LogLevel {
    case normal
    case minimal
}

