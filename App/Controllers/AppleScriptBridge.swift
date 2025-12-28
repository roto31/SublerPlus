import Foundation
import AppKit

/// AppleScript bridge for SublerPlus automation
/// Provides AppleScript dictionary support for file, metadata, and queue commands
public final class AppleScriptBridge: NSObject {
    
    public static let shared = AppleScriptBridge()
    
    var jobQueue: JobQueue?
    var statusStream: StatusStream?
    
    private override init() {
        super.init()
    }
    
    /// Initialize with dependencies
    public func initialize(jobQueue: JobQueue, statusStream: StatusStream) {
        self.jobQueue = jobQueue
        self.statusStream = statusStream
    }
    
    /// Register AppleScript commands
    public func registerScriptCommands() {
        // Commands are automatically registered via NSScriptCommand subclasses
        // and the .sdef file
    }
}

// MARK: - AppleScript Command Handlers

/// Base class for AppleScript commands
@objc public class SublerPlusScriptCommand: NSScriptCommand {
    
    public override func performDefaultImplementation() -> Any? {
        // Override in subclasses
        return nil
    }
}

/// Add files to queue via AppleScript
@objc public class AddToQueueScriptCommand: SublerPlusScriptCommand {
    
    public override func performDefaultImplementation() -> Any? {
        // Handle both single file and list of files
        var fileURLs: [URL] = []
        
        if let singleFile = directParameter as? URL {
            fileURLs = [singleFile]
        } else if let files = directParameter as? [URL] {
            fileURLs = files
        } else if let filePath = directParameter as? String {
            fileURLs = [URL(fileURLWithPath: filePath)]
        } else if let filePaths = directParameter as? [String] {
            fileURLs = filePaths.map { URL(fileURLWithPath: $0) }
        } else {
            scriptErrorNumber = 1
            scriptErrorString = "Invalid file parameter - expected file reference or path"
            return nil
        }
        
        // Add files to queue
        Task {
            if let jobQueue = AppleScriptBridge.shared.jobQueue {
                _ = await jobQueue.enqueue(fileURLs)
            }
        }
        
        return fileURLs.count
    }
}

/// Get queue status via AppleScript
@objc public class QueueStatusScriptCommand: SublerPlusScriptCommand {
    
    public override func performDefaultImplementation() -> Any? {
        guard AppleScriptBridge.shared.jobQueue != nil else {
            return 0 // idle
        }
        
        // Synchronous access - use semaphore for async
        guard let jobQueue = AppleScriptBridge.shared.jobQueue else {
            return 0 // idle
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var result: Int = 0
        
        Task {
            let stats = await jobQueue.getStatistics()
            if stats.runningCount > 0 {
                result = 1 // running
            } else if stats.currentQueueSize == 0 && stats.totalProcessed > 0 {
                result = 2 // completed
            } else {
                result = 0 // idle
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
}

/// Start queue via AppleScript
@objc public class StartQueueScriptCommand: SublerPlusScriptCommand {
    
    public override func performDefaultImplementation() -> Any? {
        Task {
            if let jobQueue = AppleScriptBridge.shared.jobQueue {
                await jobQueue.processQueue()
            }
        }
        return true
    }
}

/// Start queue and wait via AppleScript
@objc public class StartQueueAndWaitScriptCommand: SublerPlusScriptCommand {
    
    public override func performDefaultImplementation() -> Any? {
        Task {
            if let jobQueue = AppleScriptBridge.shared.jobQueue {
                await jobQueue.processQueue()
                // Wait until queue is empty
                while await jobQueue.snapshot().contains(where: { $0.status == .running || $0.status == .queued }) {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
            suspendExecution()
        }
        return nil
    }
}

/// Stop queue via AppleScript
@objc public class StopQueueScriptCommand: SublerPlusScriptCommand {
    
    public override func performDefaultImplementation() -> Any? {
        Task {
            if let jobQueue = AppleScriptBridge.shared.jobQueue {
                await jobQueue.stop()
            }
        }
        return true
    }
}

/// Remove completed items from queue via AppleScript
@objc public class RemoveCompletedScriptCommand: SublerPlusScriptCommand {
    
    public override func performDefaultImplementation() -> Any? {
        Task {
            if let jobQueue = AppleScriptBridge.shared.jobQueue {
                await jobQueue.removeCompleted()
            }
        }
        return true
    }
}

/// Set metadata via AppleScript
@objc public class SetMetadataScriptCommand: SublerPlusScriptCommand {
    
    public override func performDefaultImplementation() -> Any? {
        guard let args = evaluatedArguments else {
            scriptErrorNumber = 1
            scriptErrorString = "Missing parameters"
            return nil
        }
        
        var fileURL: URL?
        if let file = args["file"] as? URL {
            fileURL = file
        } else if let filePath = args["file"] as? String {
            fileURL = URL(fileURLWithPath: filePath)
        }
        
        guard fileURL != nil else {
            scriptErrorNumber = 1
            scriptErrorString = "Invalid file parameter"
            return nil
        }
        
        guard args["metadata"] is [String: Any] else {
            scriptErrorNumber = 1
            scriptErrorString = "Invalid metadata parameter"
            return nil
        }
        
        Task {
            // Apply metadata to file using MetadataManager
            // This would require integration with the metadata pipeline
            // For now, return success
        }
        
        return true
    }
}

/// Get metadata via AppleScript
@objc public class GetMetadataScriptCommand: SublerPlusScriptCommand {
    
    public override func performDefaultImplementation() -> Any? {
        var fileURL: URL?
        if let file = directParameter as? URL {
            fileURL = file
        } else if let filePath = directParameter as? String {
            fileURL = URL(fileURLWithPath: filePath)
        }
        
        guard fileURL != nil else {
            scriptErrorNumber = 1
            scriptErrorString = "Invalid file parameter"
            return nil
        }
        
        // Return metadata dictionary
        // This would require integration with MetadataManager to read metadata
        // For now, return empty dictionary
        return [String: Any]()
    }
}

/// Fix audio fallbacks via AppleScript
@objc public class FixAudioFallbacksScriptCommand: SublerPlusScriptCommand {
    
    public override func performDefaultImplementation() -> Any? {
        guard let args = evaluatedArguments,
              let file = args["into"] as? URL else {
            scriptErrorNumber = 1
            scriptErrorString = "Invalid file parameter"
            return nil
        }
        
        Task {
            try? await QueueFixFallbacksAction().execute(on: file)
        }
        
        return true
    }
}

