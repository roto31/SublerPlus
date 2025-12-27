import Foundation

public final class SubtitleRawImporter: RawFormatImporter {
    public let formatType: RawFormatType
    
    public init(format: RawFormatType) {
        self.formatType = format
    }
    
    public func canImport(url: URL) -> Bool {
        RawFormatHandler.detectFormat(url: url) == formatType
    }
    
    public func extractTrackInfo(from url: URL) async throws -> MediaTrack {
        switch formatType {
        case .scc:
            return try await extractSCCInfo(from: url)
        case .idx:
            return try await extractVobSubInfo(from: url)
        default:
            throw RawFormatError.unsupportedFormat
        }
    }
    
    private func extractSCCInfo(from url: URL) async throws -> MediaTrack {
        // SCC (Scenarist Closed Caption) files are text-based
        // Basic validation - check if file exists and is readable
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RawFormatError.invalidFile
        }
        
        // SCC files typically start with "Scenarist_SCC_V1.0" or contain timecode patterns
        // For now, return basic track info
        return MediaTrack(
            kind: .subtitle,
            codec: "scc",
            language: "eng", // Default, could be parsed from file
            bitrate: nil,
            isDefault: true,
            isForced: false,
            resolution: nil,
            hdr: false
        )
    }
    
    private func extractVobSubInfo(from url: URL) async throws -> MediaTrack {
        // VobSub consists of .idx (index) and .sub (bitmap) files
        // Parse .idx file to extract language and timing info
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw RawFormatError.invalidFile
        }
        
        var language: String? = "eng"
        var isForced = false
        
        // Parse .idx file format
        // Look for language line: "id: en, index: 0"
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("id:") {
                // Extract language code
                let parts = trimmed.components(separatedBy: ",")
                for part in parts {
                    let keyValue = part.trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
                    if keyValue.count == 2 && keyValue[0].trimmingCharacters(in: .whitespaces) == "id" {
                        language = keyValue[1].trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }
            if trimmed.contains("forced") {
                isForced = true
            }
        }
        
        return MediaTrack(
            kind: .subtitle,
            codec: "vobsub",
            language: language,
            bitrate: nil,
            isDefault: true,
            isForced: isForced,
            resolution: nil,
            hdr: false
        )
    }
}

