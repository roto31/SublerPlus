import XCTest
@testable import SublerPlusCore

final class SecurityInputValidationTests: XCTestCase {
    func testPipelineRejectsUnsupportedExtension() async {
        let mockHandler = MockMP4Handler()
        let pipeline = MetadataPipeline(registry: ProvidersRegistry(providers: []), mp4Handler: mockHandler, artwork: nil)
        let url = URL(fileURLWithPath: "/tmp/test.mp3")
        do {
            _ = try await pipeline.enrich(file: url, includeAdult: false)
            XCTFail("Expected unsupported type")
        } catch let error as MetadataError {
            XCTAssertEqual(error, .unsupportedFileType)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}

private final class MockMP4Handler: MP4Handler {
    func readMetadata(at url: URL) throws -> MetadataHint {
        MetadataHint(title: "x")
    }

    func writeMetadata(_ metadata: MetadataDetails, tags: [String : Any], to url: URL) throws {
        // no-op
    }
}

