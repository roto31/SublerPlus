import XCTest
@testable import SublerPlusCore
import CoreMedia

final class TX3GEncoderTests: XCTestCase {
    
    func testParseSRTBasic() throws {
        let srtContent = """
1
00:00:01,000 --> 00:00:03,500
Hello world

2
00:00:04,000 --> 00:00:06,000
This is a test
"""
        let data = srtContent.data(using: .utf8)!
        let samples = try TX3GEncoder.parseSRT(data)
        
        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples[0].text, "Hello world")
        XCTAssertEqual(samples[1].text, "This is a test")
    }
    
    func testParseSRTEmpty() throws {
        let srtContent = ""
        let data = srtContent.data(using: .utf8)!
        let samples = try TX3GEncoder.parseSRT(data)
        XCTAssertEqual(samples.count, 0)
    }
    
    func testParseWebVTTBasic() throws {
        let vttContent = """
WEBVTT

00:00:01.000 --> 00:00:03.500
Hello world

00:00:04.000 --> 00:00:06.000
This is a test
"""
        let data = vttContent.data(using: .utf8)!
        let samples = try TX3GEncoder.parseWebVTT(data)
        
        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples[0].text, "Hello world")
        XCTAssertEqual(samples[1].text, "This is a test")
    }
    
    func testParseSRTWithMultipleLines() throws {
        let srtContent = """
1
00:00:01,000 --> 00:00:03,500
Line 1
Line 2
Line 3

2
00:00:04,000 --> 00:00:06,000
Single line
"""
        let data = srtContent.data(using: .utf8)!
        let samples = try TX3GEncoder.parseSRT(data)
        
        XCTAssertEqual(samples.count, 2)
        XCTAssertTrue(samples[0].text.contains("Line 1"))
        XCTAssertTrue(samples[0].text.contains("Line 2"))
        XCTAssertTrue(samples[0].text.contains("Line 3"))
        XCTAssertEqual(samples[1].text, "Single line")
    }
}

