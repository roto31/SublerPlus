import Foundation

/// Handles MP4 brand atoms for different output formats (M4V, M4A, M4B, M4R)
public enum MP4BrandHandler {
    
    public enum OutputFormat: String, Sendable, Codable {
        case mp4 = "mp4"
        case m4v = "m4v"
        case m4a = "m4a"
        case m4b = "m4b"
        case m4r = "m4r"
        
        /// MP4 brand identifier for this format
        public var brand: String {
            switch self {
            case .mp4: return "isom" // ISO Base Media
            case .m4v: return "M4V " // iTunes video
            case .m4a: return "M4A " // iTunes audio
            case .m4b: return "M4B " // iTunes audiobook
            case .m4r: return "M4R " // iTunes ringtone
            }
        }
        
        /// Compatible brands for this format
        public var compatibleBrands: [String] {
            switch self {
            case .mp4:
                return ["isom", "iso2", "avc1", "mp41"]
            case .m4v:
                return ["M4V ", "isom", "iso2", "avc1", "mp41"]
            case .m4a:
                return ["M4A ", "isom", "iso2", "mp41"]
            case .m4b:
                return ["M4B ", "isom", "iso2", "mp41"]
            case .m4r:
                return ["M4R ", "isom", "iso2", "mp41"]
            }
        }
    }
    
    /// Update MP4 brand atoms for the specified output format
    public static func updateBrands(
        at url: URL,
        format: OutputFormat
    ) throws {
        guard var data = try? Data(contentsOf: url) else {
            throw MP4BrandError.fileReadFailed
        }
        
        // Find ftyp atom (should be at offset 4)
        guard let ftyp = AtomCodec.findAtom(in: data, type: "ftyp", start: 0, length: min(32, data.count)) else {
            // No ftyp atom - create one
            try createFtypAtom(in: &data, format: format)
            try data.write(to: url, options: .atomic)
            return
        }
        
        // Update existing ftyp atom
        let newFtyp = buildFtypAtom(format: format)
        let oldSize = ftyp.size
        let delta = newFtyp.count - oldSize
        
        // Replace ftyp atom
        data.replaceSubrange(ftyp.offset..<(ftyp.offset + oldSize), with: newFtyp)
        
        // Adjust file size if needed (if ftyp is not first atom)
        if ftyp.offset > 0 {
            // File size is typically in first 4 bytes
            if let fileSize = readUInt32(data, 0), fileSize != 0 {
                let newFileSize = UInt32(Int(fileSize) + delta)
                data.replaceSubrange(0..<4, with: newFileSize.bigEndianData)
            }
        }
        
        try data.write(to: url, options: .atomic)
    }
    
    /// Create ftyp atom for the specified format
    private static func createFtypAtom(in data: inout Data, format: OutputFormat) throws {
        let ftyp = buildFtypAtom(format: format)
        
        // Insert ftyp at the beginning (after potential file size)
        // Check if first 4 bytes are file size
        let insertOffset: Int
        if let fileSize = readUInt32(data, 0), fileSize > 0 && fileSize < 100_000_000 {
            // Likely a file size field
            insertOffset = 4
        } else {
            insertOffset = 0
        }
        
        data.insert(contentsOf: ftyp, at: insertOffset)
        
        // Update file size if present
        if insertOffset == 4 {
            let newFileSize = UInt32(data.count)
            data.replaceSubrange(0..<4, with: newFileSize.bigEndianData)
        }
    }
    
    /// Build ftyp atom for the specified format
    private static func buildFtypAtom(format: OutputFormat) -> Data {
        var ftyp = Data()
        
        // ftyp atom structure:
        // size (4 bytes) + "ftyp" (4 bytes) + major brand (4 bytes) + minor version (4 bytes) + compatible brands (4 bytes each)
        
        let compatibleBrands = format.compatibleBrands
        let atomSize = 8 + 4 + 4 + (compatibleBrands.count * 4) // size + type + major + minor + brands
        
        // Size
        ftyp.append(UInt32(atomSize).bigEndianData)
        
        // Type
        ftyp.append(AtomCodec.fourCC("ftyp"))
        
        // Major brand
        ftyp.append(AtomCodec.fourCC(format.brand))
        
        // Minor version (typically 0)
        ftyp.append(UInt32(0).bigEndianData)
        
        // Compatible brands
        for brand in compatibleBrands {
            ftyp.append(AtomCodec.fourCC(brand))
        }
        
        return ftyp
    }
    
    /// Read UInt32 from data at offset
    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        return data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }
}

public enum MP4BrandError: Error, Equatable {
    case fileReadFailed
    case invalidFormat
    case writeFailed
}

