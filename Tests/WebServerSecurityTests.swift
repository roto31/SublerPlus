import XCTest
@testable import SublerPlusCore

final class WebServerSecurityTests: XCTestCase {
    func testAuthHeaderRequiredWhenTokenSet() {
        let pipeline = MetadataPipeline(registry: ProvidersRegistry(providers: []), mp4Handler: SublerMP4Handler(), artwork: ArtworkCacheManager())
        let server = WebServer(pipeline: pipeline, registry: ProvidersRegistry(providers: []), status: StatusStream(), authToken: "secret", requireAuth: true)
        XCTAssertFalse(server.authorized(headers: [:]))
        XCTAssertTrue(server.authorized(headers: ["x-auth-token": "secret"]))
    }
    
    func testAuthRequiredByDefault() {
        let pipeline = MetadataPipeline(registry: ProvidersRegistry(providers: []), mp4Handler: SublerMP4Handler(), artwork: ArtworkCacheManager())
        let server = WebServer(pipeline: pipeline, registry: ProvidersRegistry(providers: []), status: StatusStream(), authToken: nil, requireAuth: true)
        XCTAssertFalse(server.authorized(headers: [:]))
    }
    
    func testSessionTokenAuth() {
        let pipeline = MetadataPipeline(registry: ProvidersRegistry(providers: []), mp4Handler: SublerMP4Handler(), artwork: ArtworkCacheManager())
        let server = WebServer(pipeline: pipeline, registry: ProvidersRegistry(providers: []), status: StatusStream(), authToken: "secret", requireAuth: true)
        // Session tokens are validated internally, but we can test that they're accepted
        // Note: This is a simplified test - full session token testing would require mocking time
        XCTAssertFalse(server.authorized(headers: ["x-session-token": "invalid"]))
    }

    func testContentTypeValidation() {
        let pipeline = MetadataPipeline(registry: ProvidersRegistry(providers: []), mp4Handler: SublerMP4Handler(), artwork: ArtworkCacheManager())
        let server = WebServer(pipeline: pipeline, registry: ProvidersRegistry(providers: []), status: StatusStream(), requireAuth: false)
        XCTAssertTrue(server.validateContentType(headers: ["content-type": "application/json"]))
        XCTAssertFalse(server.validateContentType(headers: ["content-type": "text/plain"]))
    }

    func testBodySizeValidation() {
        let pipeline = MetadataPipeline(registry: ProvidersRegistry(providers: []), mp4Handler: SublerMP4Handler(), artwork: ArtworkCacheManager())
        let server = WebServer(pipeline: pipeline, registry: ProvidersRegistry(providers: []), status: StatusStream(), requireAuth: false, maxBodyBytes: 10)
        XCTAssertTrue(server.validateBodySize(length: 5))
        XCTAssertFalse(server.validateBodySize(length: 11))
    }
}

