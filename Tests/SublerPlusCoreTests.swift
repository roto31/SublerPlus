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

    func testTagMappingWithTVAndSort() {
        let details = MetadataDetails(
            id: "3",
            title: "Pilot",
            synopsis: nil,
            releaseDate: nil,
            studio: "Studio",
            tags: [],
            performers: [],
            coverURL: nil,
            rating: 4.0,
            source: "tvdb",
            show: "ShowName",
            episodeID: "S01E01",
            seasonNumber: 1,
            episodeNumber: 1,
            mediaKind: .tvShow,
            sortTitle: "Pilot Sort",
            sortArtist: "Artist Sort",
            sortAlbum: "Album Sort",
            trackNumber: 1,
            trackTotal: 10,
            discNumber: 1,
            discTotal: 2,
            isHD: true,
            isHEVC: true,
            isHDR: false
        )
        let tags = mp4TagUpdates(from: details, coverData: nil)
        XCTAssertEqual(tags["tvsh"] as? String, "ShowName")
        XCTAssertEqual(tags["tven"] as? String, "S01E01")
        XCTAssertEqual(tags["tvsn"] as? Int, 1)
        XCTAssertEqual(tags["tves"] as? Int, 1)
        XCTAssertEqual(tags["stik"] as? Int, 10)
        XCTAssertEqual((tags["trkn"] as? [Int])?.first, 1)
        XCTAssertEqual((tags["disk"] as? [Int])?.first, 1)
        XCTAssertEqual(tags["sonm"] as? String, "Pilot Sort")
        XCTAssertEqual(tags["soar"] as? String, "Artist Sort")
        XCTAssertEqual(tags["soal"] as? String, "Album Sort")
        XCTAssertEqual(tags["hdvd"] as? Int, 1)
        XCTAssertEqual(tags["hevc"] as? Int, 1)
    }
}

