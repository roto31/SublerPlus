import XCTest
@testable import SublerPlusCore

final class AtomCodecTests: XCTestCase {
    private var tempFile: URL!
    
    override func setUp() {
        super.setUp()
        tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFile)
        super.tearDown()
    }
    
    func testAtomNotFound() {
        let data = Data([0x00, 0x00, 0x00, 0x08, 0x66, 0x74, 0x79, 0x70]) // Just ftyp
        let result = AtomCodec.findAtom(in: data, type: "moov", start: 0, length: data.count)
        XCTAssertNil(result)
    }
    
    func testAtomFound() {
        // Create simple atom structure: size (4 bytes, big-endian) + type (4 bytes)
        var data = Data()
        let size: UInt32 = 8
        // MP4 atoms use big-endian byte order
        var sizeBE = size.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &sizeBE) { Array($0) })
        data.append("moov".data(using: .ascii)!)
        
        let result = AtomCodec.findAtom(in: data, type: "moov", start: 0, length: data.count)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, "moov")
        XCTAssertEqual(result?.size, 8)
    }
    
    func testBuildIlstAtom() {
        let tags: [String: Any] = [
            "©nam": "Test Title",
            "©ART": "Test Artist",
            "©gen": "Action, Drama",
            "tvsh": "Show Name",
            "tvsn": 1,
            "tves": 5,
            "stik": 10,
            "hdvd": 1
        ]
        
        let ilstData = AtomCodec.buildIlst(tags: tags)
        XCTAssertGreaterThan(ilstData.count, 8) // At least ilst header
        
        // Verify ilst atom structure
        let size = UInt32(bigEndian: ilstData[0..<4].withUnsafeBytes { $0.load(as: UInt32.self) })
        XCTAssertEqual(size, UInt32(ilstData.count))
        
        let type = String(data: ilstData[4..<8], encoding: .ascii)
        XCTAssertEqual(type, "ilst")
    }
    
    func testUpdateIlstWithTags() throws {
        // Create minimal MP4
        try createMinimalMP4()
        
        let tags: [String: Any] = [
            "©nam": "Test Movie",
            "©ART": "Test Director",
            "©gen": "Sci-Fi",
            "covr": Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        ]
        
        // This should not throw (best-effort)
        XCTAssertNoThrow(try AtomCodec.updateIlst(at: tempFile, tags: tags))
        
        // Verify file still exists and is readable
        let updatedData = try Data(contentsOf: tempFile)
        XCTAssertGreaterThan(updatedData.count, 0)
    }
    
    private func createMinimalMP4() throws {
        var data = Data()
        
        // ftyp
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x20])
        data.append("ftyp".data(using: .ascii)!)
        data.append("mp41".data(using: .ascii)!)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        data.append("mp41".data(using: .ascii)!)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        
        // moov
        let moovStart = data.count
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        data.append("moov".data(using: .ascii)!)
        
        // udta
        let udtaStart = data.count
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        data.append("udta".data(using: .ascii)!)
        
        // meta
        let metaStart = data.count
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        data.append("meta".data(using: .ascii)!)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        
        // ilst (empty)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x08])
        data.append("ilst".data(using: .ascii)!)
        
        // Update sizes
        let metaSize = data.count - metaStart
        var metaSizeBE = UInt32(metaSize).bigEndian
        data.replaceSubrange(metaStart..<metaStart+4, with: Data(bytes: &metaSizeBE, count: 4))
        
        let udtaSize = data.count - udtaStart
        var udtaSizeBE = UInt32(udtaSize).bigEndian
        data.replaceSubrange(udtaStart..<udtaStart+4, with: Data(bytes: &udtaSizeBE, count: 4))
        
        let moovSize = data.count - moovStart
        var moovSizeBE = UInt32(moovSize).bigEndian
        data.replaceSubrange(moovStart..<moovStart+4, with: Data(bytes: &moovSizeBE, count: 4))
        
        try data.write(to: tempFile)
    }
}

private extension UInt32 {
    var bigEndianBytes: [UInt8] {
        var value = self.bigEndian
        return withUnsafeBytes(of: &value) { Array($0) }
    }
}

