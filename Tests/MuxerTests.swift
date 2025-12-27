import XCTest
@testable import SublerPlusCore

final class MuxerTests: XCTestCase {
    
    func testMuxingOptionsInitialization() {
        let options = MuxingOptions()
        XCTAssertFalse(options.optimize)
        XCTAssertFalse(options.use64BitData)
        XCTAssertFalse(options.use64BitTime)
        XCTAssertTrue(options.selectedTracks.isEmpty)
    }
    
    func testTrackSelectionInitialization() {
        let track = MediaTrack(kind: .video, codec: "avc1")
        let selection = TrackSelection(track: track, sourceURL: URL(fileURLWithPath: "/test.mp4"), selected: true)
        XCTAssertEqual(selection.track.kind, .video)
        XCTAssertTrue(selection.selected)
    }
    
    func testMuxingOptionsWithSelectedTracks() {
        let track1 = MediaTrack(kind: .video, codec: "avc1")
        let track2 = MediaTrack(kind: .audio, codec: "aac")
        let trackIds: Set<UUID> = [track1.id, track2.id]
        
        let options = MuxingOptions(selectedTracks: trackIds)
        XCTAssertEqual(options.selectedTracks.count, 2)
        XCTAssertTrue(options.selectedTracks.contains(track1.id))
        XCTAssertTrue(options.selectedTracks.contains(track2.id))
    }
}

