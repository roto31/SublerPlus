import XCTest
@testable import SublerPlusCore

final class ProviderRetryTests: XCTestCase {
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func testTMDBRetrySucceedsAfterFailures() async throws {
        MockURLProtocol.reset(statusCodes: [500, 502, 200], data: #"{"results":[]}"#.data(using: .utf8)!)
        let provider = StandardMetadataProvider(apiKey: "x", session: makeSession())!
        let data = try await provider.fetchWithRetry(url: URL(string: "https://example.com")!)
        XCTAssertEqual(MockURLProtocol.requestCount, 3)
        XCTAssertFalse(data.isEmpty)
    }

    func testTVDBRetrySucceedsAfterFailure() async throws {
        MockURLProtocol.reset(statusCodes: [500, 200], data: #"{"data":{"name":"t","overview":null,"firstAired":null,"network":null,"genres":[],"actors":[],"score":0,"imageURL":null}}"#.data(using: .utf8)!)
        let provider = TVDBProvider(apiKey: "x", session: makeSession())!
        let data = try await provider.fetchWithRetry(path: "series/1", attempts: 2)
        XCTAssertEqual(MockURLProtocol.requestCount, 2)
        XCTAssertFalse(data.isEmpty)
    }

    func testTPDBRetrySucceedsAfterFailure() async throws {
        MockURLProtocol.reset(statusCodes: [500, 200], data: #"{"data":[]}"#.data(using: .utf8)!)
        let client = TPDBClient(apiKey: "x", session: makeSession())
        let req = URLRequest(url: URL(string: "https://example.com")!)
        let data = try await client.fetchWithRetry(request: req, attempts: 2)
        XCTAssertEqual(MockURLProtocol.requestCount, 2)
        XCTAssertFalse(data.isEmpty)
    }
}

