import XCTest
@testable import SublerPlusCore

final class TVDBProviderTests: XCTestCase {
    private func makeSession(responses: [(URLRequest) -> (Int, Data)]) -> URLSession {
        MockURLProtocol.reset(statusCodes: [], data: Data())
        MockURLProtocol.handlers = responses
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func testLoginSearchDetails() async throws {
        let loginJSON = #"{"data":{"token":"abc","expires":4102444800}}"#.data(using: .utf8)!
        let searchJSON = #"{"data":[{"name":"Show","tvdb_id":10,"score":8.1,"first_air_time":"2021-01-01"}]}"#.data(using: .utf8)!
        let detailJSON = #"{"data":{"name":"Show","overview":"Plot","firstAired":"2021-01-01","network":"Net","genres":["Drama"],"actors":["Actor"],"score":8.1,"imageURL":"https://image/show.jpg"}}"#.data(using: .utf8)!

        var idx = 0
        let session = makeSession(responses: [
            { _ in idx+=1; return (200, loginJSON) },
            { _ in idx+=1; return (200, searchJSON) },
            { _ in idx+=1; return (200, detailJSON) }
        ])

        let provider = TVDBProvider(apiKey: "key", session: session)!
        let results = try await provider.search(query: "Show")
        XCTAssertEqual(results.first?.title, "Show")

        let details = try await provider.fetchDetails(for: "10")
        XCTAssertEqual(details.title, "Show")
        XCTAssertEqual(details.tags, ["Drama"])
        XCTAssertEqual(details.performers, ["Actor"])
        XCTAssertEqual(details.coverURL?.absoluteString, "https://image/show.jpg")
    }
}

