import Foundation

public struct Job: Identifiable, Hashable {
    public enum Status: String, Codable {
        case queued, running, succeeded, failed
    }
    public let id: UUID
    public let url: URL
    public var status: Status
    public var message: String
    public var actions: [QueueActionType: [String]] // Actions to apply
    
    public init(id: UUID = UUID(), url: URL, status: Status = .queued, message: String = "Queued", actions: [QueueActionType: [String]] = [:]) {
        self.id = id
        self.url = url
        self.status = status
        self.message = message
        self.actions = actions
    }
    
    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable conformance
    public static func == (lhs: Job, rhs: Job) -> Bool {
        lhs.id == rhs.id
    }
}

public actor JobQueue {
    private var queue: [Job] = []
    private let statusStream: StatusStream
    private var batchConfig: QueueBatchConfig?
    private var concurrencyLimit: Int
    private var runningTasks: Set<UUID> = []
    private var shouldStop: Bool = false
    
    // Statistics tracking
    private var totalProcessed: Int = 0
    private var successCount: Int = 0
    private var failureCount: Int = 0
    private var totalProcessingTime: TimeInterval = 0
    private var jobStartTimes: [UUID: Date] = [:]

    public init(concurrency: Int = 2, statusStream: StatusStream) {
        self.concurrencyLimit = concurrency
        self.statusStream = statusStream
    }

    public func snapshot() -> [Job] { queue }
    
    /// Get queue statistics
    public func getStatistics() -> QueueStatistics {
        let currentQueueSize = queue.count
        let runningCount = runningTasks.count
        
        // Calculate estimated time remaining
        let avgTimePerJob = totalProcessed > 0 ? totalProcessingTime / Double(totalProcessed) : 0
        let estimatedTimeRemaining = avgTimePerJob * Double(currentQueueSize + runningCount)
        
        return QueueStatistics(
            totalProcessed: totalProcessed,
            successCount: successCount,
            failureCount: failureCount,
            currentQueueSize: currentQueueSize,
            runningCount: runningCount,
            averageProcessingTime: avgTimePerJob,
            estimatedTimeRemaining: estimatedTimeRemaining
        )
    }
    
    /// Reset statistics
    public func resetStatistics() {
        totalProcessed = 0
        successCount = 0
        failureCount = 0
        totalProcessingTime = 0
        jobStartTimes.removeAll()
    }
    
    /// Set batch configuration for all queued jobs
    public func setBatchConfig(_ config: QueueBatchConfig) {
        batchConfig = config
    }

    @discardableResult
    public func enqueue(_ urls: [URL], with config: QueueBatchConfig? = nil) async -> [Job] {
        let configToUse = config ?? batchConfig ?? QueueBatchConfig()
        let actions = buildActions(from: configToUse)
        
        let newJobs = urls.map { url in
            Job(id: UUID(), url: url, status: .queued, message: "Queued", actions: actions)
        }
        queue.append(contentsOf: newJobs)
        return newJobs
    }
    
    /// Build action dictionary from batch config
    private func buildActions(from config: QueueBatchConfig) -> [QueueActionType: [String]] {
        var actions: [QueueActionType: [String]] = [:]
        
        if let audioLang = config.preferredAudioLanguage {
            actions[.pre, default: []].append("preferredAudio:\(audioLang)")
        }
        
        if let subtitleLang = config.preferredSubtitleLanguage {
            actions[.pre, default: []].append("preferredSubtitle:\(subtitleLang)")
        }
        
        if config.fixFallbacks {
            actions[.pre, default: []].append("fixFallbacks")
        }
        
        if let lang = config.setLanguage {
            actions[.pre, default: []].append("setLanguage:\(lang)")
        }
        
        if config.clearTrackNames {
            actions[.pre, default: []].append("clearTrackNames")
        }
        
        if config.organizeGroups {
            actions[.pre, default: []].append("organizeGroups")
        }
        
        if config.optimize {
            actions[.post, default: []].append("optimize")
        }
        
        return actions
    }
    
    /// Stop processing queue
    public func stop() async {
        shouldStop = true
        await statusStream.add("Queue stop requested")
    }
    
    /// Process queue with batch actions
    public func processQueue() async {
        shouldStop = false
        while !queue.isEmpty && !shouldStop {
            // Track start time for statistics
            let jobId = queue.first?.id
            if let id = jobId {
                jobStartTimes[id] = Date()
            }
            // Find next queued job
            guard let jobIndex = queue.firstIndex(where: { $0.status == .queued && !runningTasks.contains($0.id) }),
                  runningTasks.count < concurrencyLimit else {
                try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1s
                continue
            }
            
            let job = queue[jobIndex]
            runningTasks.insert(job.id)
            
            await update(jobID: job.id, status: .running, message: "Processing...")
            
            Task {
                do {
                    // Apply pre-muxing actions
                    try await applyActions(job.actions[.pre] ?? [], to: job.url)
                    
                    // Perform muxing/enrichment (would be called from elsewhere)
                    // For now, mark as succeeded
                    await update(jobID: job.id, status: .succeeded, message: "Completed")
                    
                    // Apply post-muxing actions
                    try await applyActions(job.actions[.post] ?? [], to: job.url)
                    
                } catch {
                    await update(jobID: job.id, status: .failed, message: error.localizedDescription)
                }
                
                runningTasks.remove(job.id)
            }
        }
    }
    
    /// Apply actions to a file
    private func applyActions(_ actionStrings: [String], to file: URL) async throws {
        for actionString in actionStrings {
            if actionString.hasPrefix("preferredAudio:") {
                let lang = String(actionString.dropFirst("preferredAudio:".count))
                try await QueuePreferredTrackAction(trackKind: .audio, preferredLanguage: lang).execute(on: file)
            } else if actionString.hasPrefix("preferredSubtitle:") {
                let lang = String(actionString.dropFirst("preferredSubtitle:".count))
                try await QueuePreferredTrackAction(trackKind: .subtitle, preferredLanguage: lang).execute(on: file)
            } else if actionString == "fixFallbacks" {
                try await QueueFixFallbacksAction().execute(on: file)
            } else if actionString.hasPrefix("setLanguage:") {
                let lang = String(actionString.dropFirst("setLanguage:".count))
                try await QueueSetLanguageAction(language: lang).execute(on: file)
            } else if actionString == "clearTrackNames" {
                try await QueueClearTrackNameAction().execute(on: file)
            } else if actionString == "organizeGroups" {
                try await QueueOrganizeGroupsAction().execute(on: file)
            } else if actionString == "optimize" {
                // Optimization would be handled by Muxer
            }
        }
    }

    public func update(jobID: UUID, status: Job.Status, message: String) async {
        if let idx = queue.firstIndex(where: { $0.id == jobID }) {
            let oldStatus = queue[idx].status
            queue[idx].status = status
            queue[idx].message = message
            
            // Track statistics
            if oldStatus == .running && (status == .succeeded || status == .failed) {
                totalProcessed += 1
                
                if let startTime = jobStartTimes[jobID] {
                    let processingTime = Date().timeIntervalSince(startTime)
                    totalProcessingTime += processingTime
                    jobStartTimes.removeValue(forKey: jobID)
                }
                
                if status == .succeeded {
                    successCount += 1
                } else if status == .failed {
                    failureCount += 1
                }
            }
        }
        await statusStream.add("\(status.rawValue.capitalized): \(message)")
    }

    public func retry(jobID: UUID) async {
        if let idx = queue.firstIndex(where: { $0.id == jobID }) {
            queue[idx].status = .queued
            queue[idx].message = "Retry queued"
        }
        await statusStream.add("Retry queued for \(jobID)")
    }
    
    /// Remove completed jobs
    public func removeCompleted() async {
        queue.removeAll { $0.status == .succeeded || $0.status == .failed }
    }
    
    /// Clear entire queue
    public func clear() async {
        queue.removeAll()
        runningTasks.removeAll()
    }
}

/// Queue statistics
public struct QueueStatistics: Sendable {
    public let totalProcessed: Int
    public let successCount: Int
    public let failureCount: Int
    public let currentQueueSize: Int
    public let runningCount: Int
    public let averageProcessingTime: TimeInterval
    public let estimatedTimeRemaining: TimeInterval
}

/// Queue sort order
public enum QueueSortOrder: Sendable {
    case urlAscending
    case urlDescending
    case status
    case addedFirst
    case addedLast
}

