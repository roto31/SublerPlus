import Foundation

final class CircuitBreaker {
    private let failureThreshold: Int
    private let resetAfter: TimeInterval
    private var failures: Int = 0
    private var lastFailure: Date?
    private let lock = DispatchQueue(label: "com.sublerplus.circuitbreaker")

    init(failureThreshold: Int = 3, resetAfter: TimeInterval = 30) {
        self.failureThreshold = failureThreshold
        self.resetAfter = resetAfter
    }

    func allow() -> Bool {
        lock.sync {
            if let lastFailure, Date().timeIntervalSince(lastFailure) > resetAfter {
                failures = 0
            }
            return failures < failureThreshold
        }
    }

    func recordSuccess() {
        lock.sync {
            failures = 0
            lastFailure = nil
        }
    }

    func recordFailure() {
        lock.sync {
            failures += 1
            lastFailure = Date()
        }
    }
}

