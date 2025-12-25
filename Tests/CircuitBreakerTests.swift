import XCTest
@testable import SublerPlusCore

final class CircuitBreakerTests: XCTestCase {
    func testTripsAfterFailures() {
        let breaker = CircuitBreaker(failureThreshold: 2, resetAfter: 30)
        XCTAssertTrue(breaker.allow())
        breaker.recordFailure()
        XCTAssertTrue(breaker.allow())
        breaker.recordFailure()
        XCTAssertFalse(breaker.allow())
    }
}

