import XCTest
@testable import SublerPlusCore
import Swifter

final class WebServerCORSTests: XCTestCase {
    func testCorsPreflightResponse() {
        let pipeline = MetadataPipeline(registry: ProvidersRegistry(providers: []), mp4Handler: SublerMP4Handler(), artwork: ArtworkCacheManager())
        let server = WebServer(pipeline: pipeline, registry: ProvidersRegistry(providers: []), status: StatusStream())
        let resp = server.corsPreflightResponse()
        switch resp {
        case .raw(_, _, let headers, _):
            XCTAssertEqual(headers?["Access-Control-Allow-Origin"], "http://127.0.0.1:8080")
            XCTAssertEqual(headers?["Access-Control-Allow-Methods"], "POST, GET, OPTIONS")
        default:
            XCTFail("Unexpected response type")
        }
    }
}

