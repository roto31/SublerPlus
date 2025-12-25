import Foundation

public struct Job: Identifiable, Hashable, Codable {
    public enum Status: String, Codable {
        case queued, running, succeeded, failed
    }
    public let id: UUID
    public let url: URL
    public var status: Status
    public var message: String
}

public actor JobQueue {
    private var queue: [Job] = []
    private let statusStream: StatusStream

    public init(concurrency: Int = 2, statusStream: StatusStream) {
        self.statusStream = statusStream
    }

    public func snapshot() -> [Job] { queue }

    @discardableResult
    public func enqueue(_ urls: [URL]) async -> [Job] {
        let newJobs = urls.map { Job(id: UUID(), url: $0, status: .queued, message: "Queued") }
        queue.append(contentsOf: newJobs)
        return newJobs
    }

    public func update(jobID: UUID, status: Job.Status, message: String) async {
        if let idx = queue.firstIndex(where: { $0.id == jobID }) {
            queue[idx].status = status
            queue[idx].message = message
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
}

