import Foundation
import os.log

// Unified logging to the macOS Console (persistent store).
// Subsystem: com.sublerplus.app
// Categories: general, network, providers, pipeline, webui, storage

public enum AppLog {
    private static let subsystem = "com.sublerplus.app"

    public static let general = Logger(subsystem: subsystem, category: "general")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let providers = Logger(subsystem: subsystem, category: "providers")
    public static let pipeline = Logger(subsystem: subsystem, category: "pipeline")
    public static let webui = Logger(subsystem: subsystem, category: "webui")
    public static let storage = Logger(subsystem: subsystem, category: "storage")

    public static var level: LogLevel = {
        if let env = ProcessInfo.processInfo.environment["LOG_LEVEL"]?.lowercased(), env == "minimal" {
            return .minimal
        }
        return .normal
    }()

    public static func info(_ logger: Logger = AppLog.general, _ message: String) {
        guard level == .normal else { return }
        logger.log("\(scrubSecrets(message), privacy: .public)")
    }

    public static func error(_ logger: Logger = AppLog.general, _ message: String) {
        logger.error("\(scrubSecrets(message), privacy: .public)")
    }
}

/// Scrub API keys or bearer tokens from log strings before writing to the unified log store.
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

