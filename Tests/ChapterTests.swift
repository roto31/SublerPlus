import XCTest
@testable import SublerPlusCore

final class ChapterTests: XCTestCase {
    func testChapterParsing() {
        let chapterText = """
        00:00:00 Chapter 1
        00:05:30 Chapter 2
        00:12:45 Chapter 3
        01:23:15 Final Chapter
        """
        
        let chapters = parseChapters(text: chapterText)
        XCTAssertEqual(chapters.count, 4)
        XCTAssertEqual(chapters[0].title, "Chapter 1")
        XCTAssertEqual(chapters[0].startSeconds, 0.0, accuracy: 0.1)
        XCTAssertEqual(chapters[1].title, "Chapter 2")
        XCTAssertEqual(chapters[1].startSeconds, 330.0, accuracy: 0.1) // 5:30 = 330 seconds
        XCTAssertEqual(chapters[2].title, "Chapter 3")
        XCTAssertEqual(chapters[2].startSeconds, 765.0, accuracy: 0.1) // 12:45 = 765 seconds
        XCTAssertEqual(chapters[3].title, "Final Chapter")
        XCTAssertEqual(chapters[3].startSeconds, 4995.0, accuracy: 0.1) // 1:23:15 = 4995 seconds
    }
    
    func testChapterTimeFormatting() {
        let seconds: Double = 3661.0 // 1:01:01
        let formatted = formatChapterTime(seconds)
        XCTAssertEqual(formatted, "01:01:01")
        
        let short: Double = 125.0 // 2:05
        let formattedShort = formatChapterTime(short)
        XCTAssertEqual(formattedShort, "02:05")
        
        let veryShort: Double = 45.0 // 0:45
        let formattedVeryShort = formatChapterTime(veryShort)
        XCTAssertEqual(formattedVeryShort, "00:45")
    }
    
    func testChapterExportFormat() {
        let chapters = [
            Chapter(title: "Introduction", startSeconds: 0.0),
            Chapter(title: "Main Content", startSeconds: 300.0),
            Chapter(title: "Conclusion", startSeconds: 600.0)
        ]
        
        let exported = chapters.map { chapter in
            "\(formatChapterTime(chapter.startSeconds)) \(chapter.title)"
        }.joined(separator: "\n")
        
        // formatChapterTime only includes hours if h > 0, otherwise uses MM:SS format
        XCTAssertTrue(exported.contains("00:00 Introduction"))
        XCTAssertTrue(exported.contains("05:00 Main Content"))
        XCTAssertTrue(exported.contains("10:00 Conclusion"))
    }
    
    func testChapterParsingWithInvalidTime() {
        let invalidText = """
        invalid time Chapter 1
        00:05:30 Valid Chapter
        """
        
        let chapters = parseChapters(text: invalidText)
        // Should skip invalid lines and parse valid ones
        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(chapters[0].title, "Valid Chapter")
    }
    
    func testChapterParsingEmptyLines() {
        let textWithEmptyLines = """
        00:00:00 Chapter 1

        00:05:30 Chapter 2

        00:10:00 Chapter 3
        """
        
        let chapters = parseChapters(text: textWithEmptyLines)
        XCTAssertEqual(chapters.count, 3)
    }
    
    func testChapterParsingMissingTitle() {
        let textMissingTitle = """
        00:00:00
        00:05:30 Chapter With Title
        """
        
        let chapters = parseChapters(text: textMissingTitle)
        // Should handle gracefully - may create default title or skip
        XCTAssertGreaterThanOrEqual(chapters.count, 1)
    }
}

// Helper functions matching ViewModels implementation
private func parseChapters(text: String) -> [Chapter] {
    var chapters: [Chapter] = []
    let lines = text.split(whereSeparator: \.isNewline)
    
    for line in lines {
        let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count >= 1 else { continue }
        let timeString = String(parts[0])
        let title = parts.count == 2 ? String(parts[1]) : "Chapter \(chapters.count + 1)"
        if let seconds = parseTime(timeString) {
            chapters.append(Chapter(title: title, startSeconds: seconds))
        }
    }
    return chapters
}

private func parseTime(_ str: String) -> Double? {
    let parts = str.split(separator: ":").reversed()
    var total: Double = 0
    for (idx, part) in parts.enumerated() {
        guard let val = Double(part) else { return nil }
        total += val * pow(60, Double(idx))
    }
    return total
}

private func formatChapterTime(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 {
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    return String(format: "%02d:%02d", m, s)
}

