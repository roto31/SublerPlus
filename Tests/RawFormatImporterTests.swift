import XCTest
@testable import SublerPlusCore

final class RawFormatImporterTests: XCTestCase {
    
    func testDetectH264Format() {
        let url = URL(fileURLWithPath: "/test/file.h264")
        let format = RawFormatHandler.detectFormat(url: url)
        XCTAssertEqual(format, .h264)
    }
    
    func testDetectAACFormat() {
        let url = URL(fileURLWithPath: "/test/file.aac")
        let format = RawFormatHandler.detectFormat(url: url)
        XCTAssertEqual(format, .aac)
    }
    
    func testDetectAC3Format() {
        let url = URL(fileURLWithPath: "/test/file.ac3")
        let format = RawFormatHandler.detectFormat(url: url)
        XCTAssertEqual(format, .ac3)
    }
    
    func testCreateH264Importer() {
        let url = URL(fileURLWithPath: "/test/file.h264")
        let importer = RawFormatHandler.createImporter(for: url)
        XCTAssertNotNil(importer)
        XCTAssertEqual(importer?.formatType, .h264)
    }
    
    func testCreateAACImporter() {
        let url = URL(fileURLWithPath: "/test/file.aac")
        let importer = RawFormatHandler.createImporter(for: url)
        XCTAssertNotNil(importer)
        XCTAssertEqual(importer?.formatType, .aac)
    }
}

