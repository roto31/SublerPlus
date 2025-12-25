import XCTest
@testable import SublerPlusCore

final class SublerPlusCoreTests: XCTestCase {
    func testTagMapping() {
        let details = MetadataDetails(
            id: "1",
            title: "Sample",
            synopsis: nil,
            releaseDate: nil,
            studio: nil,
            tags: ["Action", "Drama"],
            performers: ["Actor"],
            coverURL: nil,
            rating: nil
        )
        let tags = mp4TagUpdates(from: details, coverData: nil)
        XCTAssertEqual(tags["©nam"] as? String, "Sample")
        XCTAssertEqual(tags["©gen"] as? String, "Action, Drama")
    }

    func testTagMappingWithCover() {
        let cover = Data([0xFF, 0xD8, 0xFF]) // jpeg header bytes
        let details = MetadataDetails(
            id: "2",
            title: "WithCover",
            synopsis: nil,
            releaseDate: nil,
            studio: nil,
            tags: [],
            performers: [],
            coverURL: nil,
            rating: nil
        )
        let tags = mp4TagUpdates(from: details, coverData: cover)
        XCTAssertEqual(tags["covr"] as? Data, cover)
    }
}

