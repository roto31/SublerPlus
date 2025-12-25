import Foundation

public actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(_ value: Int) {
        self.permits = max(0, value)
    }

    public func acquire() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    public func release() {
        if !waiters.isEmpty {
            let c = waiters.removeFirst()
            c.resume()
        } else {
            permits += 1
        }
    }
}

