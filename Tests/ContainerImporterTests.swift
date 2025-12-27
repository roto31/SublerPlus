import XCTest
@testable import SublerPlusCore

final class ContainerImporterTests: XCTestCase {
    
    func testDetectFormatMP4() {
        let url = URL(fileURLWithPath: "/test/file.mp4")
        let format = ContainerImporter.detectFormat(url: url)
        XCTAssertEqual(format, .mp4)
    }
    
    func testDetectFormatMOV() {
        let url = URL(fileURLWithPath: "/test/file.mov")
        let format = ContainerImporter.detectFormat(url: url)
        XCTAssertEqual(format, .mov)
    }
    
    func testDetectFormatMKV() {
        let url = URL(fileURLWithPath: "/test/file.mkv")
        let format = ContainerImporter.detectFormat(url: url)
        XCTAssertEqual(format, .mkv)
    }
    
    func testDetectFormatBySignature() {
        // Create a minimal MP4 file signature
        var data = Data()
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x20]) // size
        data.append("ftyp".data(using: .ascii)!)
        data.append("mp41".data(using: .ascii)!)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        try? data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let format = ContainerImporter.detectFormat(url: tempURL)
        XCTAssertEqual(format, .mp4)
    }
}

