import XCTest
@testable import SublerPlusCore

final class WebServerSecurityTests: XCTestCase {
    func testAuthHeaderRequiredWhenTokenSet() {
        let pipeline = MetadataPipeline(registry: ProvidersRegistry(providers: []), mp4Handler: SublerMP4Handler(), artwork: ArtworkCacheManager())
        let server = WebServer(pipeline: pipeline, registry: ProvidersRegistry(providers: []), status: StatusStream(), authToken: "secret")
        XCTAssertFalse(server.authorized(headers: [:]))
        XCTAssertTrue(server.authorized(headers: ["x-auth-token": "secret"]))
    }

    func testContentTypeValidation() {
        let pipeline = MetadataPipeline(registry: ProvidersRegistry(providers: []), mp4Handler: SublerMP4Handler(), artwork: ArtworkCacheManager())
        let server = WebServer(pipeline: pipeline, registry: ProvidersRegistry(providers: []), status: StatusStream())
        XCTAssertTrue(server.validateContentType(headers: ["content-type": "application/json"]))
        XCTAssertFalse(server.validateContentType(headers: ["content-type": "text/plain"]))
    }

    func testBodySizeValidation() {
        let pipeline = MetadataPipeline(registry: ProvidersRegistry(providers: []), mp4Handler: SublerMP4Handler(), artwork: ArtworkCacheManager())
        let server = WebServer(pipeline: pipeline, registry: ProvidersRegistry(providers: []), status: StatusStream(), maxBodyBytes: 10)
        XCTAssertTrue(server.validateBodySize(length: 5))
        XCTAssertFalse(server.validateBodySize(length: 11))
    }
}

