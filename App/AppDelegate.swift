import Foundation
import AppKit
import SublerPlusCore

/// AppDelegate for AppleScript support
@objc(SPLAppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var jobQueue: JobQueue?
    private var statusStream: StatusStream?
    
    func initialize(jobQueue: JobQueue, statusStream: StatusStream) {
        self.jobQueue = jobQueue
        self.statusStream = statusStream
    }
    
    // MARK: - AppleScript Support
    
    func application(_ sender: NSApplication, delegateHandlesKey key: String) -> Bool {
        if key == "queueItems" {
            return true
        }
        return false
    }
    
    @objc(queueItems) func queueItems() -> [SPLQueueItem] {
        guard let jobQueue = jobQueue else { return [] }
        
        // Use a semaphore to wait for async result
        let semaphore = DispatchSemaphore(value: 0)
        var result: [SPLQueueItem] = []
        
        Task {
            let jobs = await jobQueue.snapshot()
            result = jobs.map { SPLQueueItem(job: $0) }
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    @MainActor @objc(insertObject:inItemsAtIndex:) func insert(object: SPLQueueItem, inItemsAtIndex index: UInt) {
        // This would add a queue item - for now, we'll skip this
        // as queue items are typically added via the add to queue command
    }
    
    @MainActor @objc(removeObjectFromItemsAtIndex:) func removeObjectFromItemsAtIndex(_ index: UInt) {
        guard let jobQueue = jobQueue else { return }
        Task {
            let jobs = await jobQueue.snapshot()
            if Int(index) < jobs.count {
                // Remove job at index - would need a remove method in JobQueue
            }
        }
    }
}
