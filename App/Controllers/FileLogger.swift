import Foundation
import os.log

/// File-based logger that streams logs to a file in the project folder
/// Supports log rotation and thread-safe writing
public actor FileLogger {
    
    // MARK: - Properties
    
    private let logFileURL: URL
    private let maxFileSize: Int64 // Maximum file size in bytes before rotation
    private let maxBackupFiles: Int // Maximum number of backup log files
    private let queue: DispatchQueue
    private var fileHandle: FileHandle?
    private var currentFileSize: Int64 = 0
    
    // MARK: - Initialization
    
    /// Initialize file logger with a log file in the project folder
    /// - Parameters:
    ///   - fileName: Name of the log file (default: "sublerplus.log")
    ///   - maxFileSize: Maximum file size in bytes before rotation (default: 10MB)
    ///   - maxBackupFiles: Maximum number of backup files to keep (default: 5)
    public init(
        fileName: String = "sublerplus.log",
        maxFileSize: Int64 = 10 * 1024 * 1024, // 10MB
        maxBackupFiles: Int = 5
    ) {
        // Determine project folder - try to find the project root
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath
        var searchPath = URL(fileURLWithPath: currentPath)
        var projectDir: URL = URL(fileURLWithPath: currentPath) // Default to current directory
        
        // Walk up the directory tree to find project root
        while searchPath.path != "/" {
            let packageSwift = searchPath.appendingPathComponent("Package.swift")
            let gitDir = searchPath.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: packageSwift.path) || fileManager.fileExists(atPath: gitDir.path) {
                projectDir = searchPath
                break
            }
            searchPath = searchPath.deletingLastPathComponent()
        }
        
        // If we didn't find project root, try application support as fallback
        if projectDir.path == currentPath {
            if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                projectDir = appSupport.appendingPathComponent("SublerPlus", isDirectory: true)
            }
        }
        
        // Create logs directory in project folder
        let logsDir = projectDir.appendingPathComponent("logs", isDirectory: true)
        
        // Create logs directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        self.logFileURL = logsDir.appendingPathComponent(fileName)
        self.maxFileSize = maxFileSize
        self.maxBackupFiles = maxBackupFiles
        self.queue = DispatchQueue(label: "com.sublerplus.filelogger", qos: .utility)
        
        // Initialize file handle synchronously (we'll do it in init)
        // Note: We can't use Task in init, so we'll initialize lazily on first write
    }
    
    // MARK: - File Management
    
    private func initializeFileHandle() {
        // Create log file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        // Open file handle for appending
        do {
            let handle = try FileHandle(forWritingTo: logFileURL)
            handle.seekToEndOfFile()
            fileHandle = handle
            currentFileSize = try FileManager.default.attributesOfItem(atPath: logFileURL.path)[.size] as? Int64 ?? 0
        } catch {
            // Fallback: try to create file and open again
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            do {
                let handle = try FileHandle(forWritingTo: logFileURL)
                handle.seekToEndOfFile()
                fileHandle = handle
                currentFileSize = 0
            } catch {
                // If we can't open the file, log to console as fallback
                os_log("Failed to open log file: %{public}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }
    
    private func rotateLogIfNeeded() {
        guard currentFileSize >= maxFileSize else { return }
        
        // Close current file handle
        fileHandle?.closeFile()
        fileHandle = nil
        
        // Rotate existing backups
        for i in (1..<maxBackupFiles).reversed() {
            let oldBackup = logFileURL.appendingPathExtension("\(i)")
            let newBackup = logFileURL.appendingPathExtension("\(i + 1)")
            
            if FileManager.default.fileExists(atPath: oldBackup.path) {
                try? FileManager.default.moveItem(at: oldBackup, to: newBackup)
            }
        }
        
        // Move current log to backup.1
        let firstBackup = logFileURL.appendingPathExtension("1")
        try? FileManager.default.moveItem(at: logFileURL, to: firstBackup)
        
        // Create new log file
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        currentFileSize = 0
        
        // Reopen file handle
        do {
            let handle = try FileHandle(forWritingTo: logFileURL)
            handle.seekToEndOfFile()
            fileHandle = handle
        } catch {
            os_log("Failed to reopen log file after rotation: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
    
    // MARK: - Logging
    
    /// Write a log entry to the file
    /// - Parameters:
    ///   - level: Log level (INFO, ERROR, etc.)
    ///   - category: Log category (general, network, etc.)
    ///   - message: Log message
    public func log(level: String, category: String, message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] [\(level)] [\(category)] \(message)\n"
        
        guard let data = logEntry.data(using: .utf8) else { return }
        
        // Write synchronously on the queue to ensure order
        queue.async { [weak self] in
            guard let self = self else { return }
            Task {
                await self.writeData(data)
            }
        }
    }
    
    private func writeData(_ data: Data) {
        // Initialize file handle if needed
        if fileHandle == nil {
            initializeFileHandle()
        }
        
        // Check if rotation is needed
        rotateLogIfNeeded()
        
        guard let handle = fileHandle else {
            // If we still don't have a handle, try one more time
            initializeFileHandle()
            guard let handle = fileHandle else { return }
            handle.write(data)
            currentFileSize += Int64(data.count)
            handle.synchronizeFile()
            return
        }
        
        handle.write(data)
        currentFileSize += Int64(data.count)
        handle.synchronizeFile() // Ensure data is written to disk
    }
    
    // MARK: - Public Methods
    
    /// Get the current log file URL
    public var fileURL: URL {
        logFileURL
    }
    
    /// Clear the log file
    public func clear() {
        fileHandle?.closeFile()
        fileHandle = nil
        
        // Remove log file
        try? FileManager.default.removeItem(at: logFileURL)
        
        // Reinitialize
        initializeFileHandle()
    }
    
    /// Close the file handle (call before app termination)
    public func close() {
        fileHandle?.closeFile()
        fileHandle = nil
    }
    
    /// Get current log file size
    public var fileSize: Int64 {
        currentFileSize
    }
}

// MARK: - Global File Logger Instance

/// Global file logger instance
public let globalFileLogger = FileLogger()

// MARK: - AppLog Extension

extension AppLog {
    /// Write to both unified logging and file logger
    /// - Parameters:
    ///   - logger: The logger instance (used to determine category)
    ///   - message: The log message
    ///   - category: Optional explicit category name (if not provided, will try to infer from logger)
    public static func infoToFile(_ logger: Logger = AppLog.general, _ message: String, category: String? = nil) {
        info(logger, message)
        let cat = category ?? getCategoryName(from: logger)
        Task {
            await globalFileLogger.log(level: "INFO", category: cat, message: scrubSecrets(message))
        }
    }
    
    /// Write error to both unified logging and file logger
    /// - Parameters:
    ///   - logger: The logger instance (used to determine category)
    ///   - message: The log message
    ///   - category: Optional explicit category name (if not provided, will try to infer from logger)
    public static func errorToFile(_ logger: Logger = AppLog.general, _ message: String, category: String? = nil) {
        error(logger, message)
        let cat = category ?? getCategoryName(from: logger)
        Task {
            await globalFileLogger.log(level: "ERROR", category: cat, message: scrubSecrets(message))
        }
    }
    
    /// Write debug message to file logger only (not to unified logging)
    /// - Parameters:
    ///   - logger: The logger instance (used to determine category)
    ///   - message: The log message
    ///   - category: Optional explicit category name (if not provided, will try to infer from logger)
    public static func debugToFile(_ logger: Logger = AppLog.general, _ message: String, category: String? = nil) {
        guard level == .normal else { return }
        let cat = category ?? getCategoryName(from: logger)
        Task {
            await globalFileLogger.log(level: "DEBUG", category: cat, message: scrubSecrets(message))
        }
    }
}

// MARK: - Category Helper

/// Helper to get category name from logger
/// Since Logger is a struct, we can't use identity comparison
/// Instead, we'll pass the category name explicitly or use a default
private func getCategoryName(from logger: Logger, defaultCategory: String = "general") -> String {
    // Try to extract from logger's description (best effort)
    let description = String(describing: logger)
    if description.contains("category: \"general\"") { return "general" }
    if description.contains("category: \"network\"") { return "network" }
    if description.contains("category: \"providers\"") { return "providers" }
    if description.contains("category: \"pipeline\"") { return "pipeline" }
    if description.contains("category: \"webui\"") { return "webui" }
    if description.contains("category: \"storage\"") { return "storage" }
    return defaultCategory
}

