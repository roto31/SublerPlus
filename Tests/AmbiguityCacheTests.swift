import XCTest
@testable import SublerPlusCore

final class AmbiguityCacheTests: XCTestCase {
    func testResolutionCacheCodable() throws {
        let key = AmbiguityResolutionKey(title: "movie", year: 2020, studio: "studio")
        let details = MetadataDetails(
            id: "1",
            title: "Title",
            synopsis: "Plot",
            releaseDate: Date(timeIntervalSince1970: 0),
            studio: "studio",
            tags: ["tag"],
            performers: ["actor"],
            coverURL: nil,
            rating: 8.0
        )
        let dict: [AmbiguityResolutionKey: MetadataDetails] = [key: details]
        let data = try JSONEncoder().encode(dict)
        let decoded = try JSONDecoder().decode([AmbiguityResolutionKey: MetadataDetails].self, from: data)
        XCTAssertEqual(decoded[key]?.title, "Title")
    }
}

