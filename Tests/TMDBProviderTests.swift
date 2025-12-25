import XCTest
@testable import SublerPlusCore

final class TMDBProviderTests: XCTestCase {
    private func makeSession(responses: [(URLRequest) -> (Int, Data)]) -> URLSession {
        MockURLProtocol.reset(statusCodes: [], data: Data())
        MockURLProtocol.handlers = responses
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func testConfigSearchAndDetails() async throws {
        let configJSON = """
        {"images":{"base_url":"http://image/","secure_base_url":"https://image/","poster_sizes":["w200","w500"]}}
        """.data(using: .utf8)!
        let searchJSON = """
        {"results":[{"id":1,"title":"Movie","release_date":"2020-01-01","vote_average":7.5}]}
        """.data(using: .utf8)!
        let detailJSON = """
        {"id":1,"title":"Movie","overview":"Plot","release_date":"2020-01-01","genres":[{"id":1,"name":"Action"}],"production_companies":[{"id":1,"name":"Studio"}],"vote_average":7.5,"poster_path":"/poster.jpg"}
        """.data(using: .utf8)!
        let creditsJSON = """
        {"cast":[{"name":"Actor1"},{"name":"Actor2"}]}
        """.data(using: .utf8)!

        var callIndex = 0
        let session = makeSession(responses: [
            { _ in callIndex+=1; return (200, configJSON) },
            { _ in callIndex+=1; return (200, searchJSON) },
            { _ in callIndex+=1; return (200, detailJSON) },
            { _ in callIndex+=1; return (200, creditsJSON) },
        ])

        let provider = StandardMetadataProvider(apiKey: "key", session: session)!
        let results = try await provider.search(query: "Movie")
        XCTAssertEqual(results.first?.title, "Movie")

        let details = try await provider.fetchDetails(for: "1")
        XCTAssertEqual(details.title, "Movie")
        XCTAssertEqual(details.tags, ["Action"])
        XCTAssertEqual(details.performers, ["Actor1","Actor2"])
        XCTAssertEqual(details.coverURL?.absoluteString, "https://image/w500/poster.jpg")
    }
}

