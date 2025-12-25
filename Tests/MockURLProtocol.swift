import Foundation

final class MockURLProtocol: URLProtocol {
    static var statusCodes: [Int] = [200]
    static var responseData: Data = Data()
    static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let idx = min(MockURLProtocol.requestCount, MockURLProtocol.statusCodes.count - 1)
        let status = MockURLProtocol.statusCodes[idx]
        MockURLProtocol.requestCount += 1

        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: MockURLProtocol.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func reset(statusCodes: [Int], data: Data) {
        self.statusCodes = statusCodes
        self.responseData = data
        self.requestCount = 0
    }
}

