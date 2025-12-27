import Foundation
import AppKit

/// Scriptable queue item for AppleScript support
@objc(SPLQueueItem)
public class SPLQueueItem: NSObject {
    private let job: Job
    
    public init(job: Job) {
        self.job = job
        super.init()
    }
    
    // MARK: - AppleScript Properties
    
    @objc public var uniqueID: String {
        return job.id.uuidString
    }
    
    @objc public var status: Int {
        switch job.status {
        case .queued: return 0
        case .running: return 1
        case .succeeded: return 2
        case .failed: return 3
        }
    }
    
    @objc public var name: String {
        return job.url.lastPathComponent
    }
    
    @objc public var sourcePath: String {
        return job.url.path
    }
    
    @objc public var destinationPath: String {
        // For now, destination is same as source
        // In future, this could be set based on output directory
        return job.url.path
    }
    
    // MARK: - Object Specifier
    
    public override var objectSpecifier: NSScriptObjectSpecifier? {
        get {
            let appDescription = NSApp.classDescription
            if let classDesc = appDescription as? NSScriptClassDescription {
                return NSUniqueIDSpecifier(
                    containerClassDescription: classDesc,
                    containerSpecifier: nil,
                    key: "queueItems",
                    uniqueID: uniqueID
                )
            }
            return nil
        }
    }
}

