import XCTest
@testable import SublerPlusCore

final class SecurityLoggingTests: XCTestCase {
    func testScrubApiKey() {
        let input = "failed call api_key=SECRET123"
        let result = scrubSecrets(input)
        XCTAssertFalse(result.contains("SECRET123"))
        XCTAssertTrue(result.contains("***"))
    }

    func testScrubBearer() {
        let input = "Authorization: Bearer TOKEN456"
        let result = scrubSecrets(input)
        XCTAssertFalse(result.contains("TOKEN456"))
    }
}

