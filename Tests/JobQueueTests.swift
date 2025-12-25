import XCTest
@testable import SublerPlusCore

final class JobQueueTests: XCTestCase {
    func testEnqueueAndRetry() async throws {
        let status = StatusStream()
        let queue = JobQueue(concurrency: 1, statusStream: status)
        _ = await queue.enqueue([URL(fileURLWithPath: "/tmp/a.mp4")])
        let snap1 = await queue.snapshot()
        XCTAssertEqual(snap1.count, 1)
        XCTAssertEqual(snap1.first?.status, .queued)

        if let id = snap1.first?.id {
            await queue.update(jobID: id, status: .failed, message: "fail")
            await queue.retry(jobID: id)
        }
        let snap2 = await queue.snapshot()
        XCTAssertEqual(snap2.first?.status, .queued)
    }
}

