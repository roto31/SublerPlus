import Foundation

/// Minimal ISO BMFF atom utilities for ilst metadata updates without ObjC/C shims.
enum AtomCodecError: Error {
    case fileReadFailed
    case structureMissing
    case writeFailed
}

struct Atom {
    let offset: Int
    let size: Int
    let type: String
    let payloadRange: Range<Int>
}

enum AtomCodec {
    /// Update or replace the `ilst` atom contents with the provided tags inside moov/udta/meta.
    /// Tags supported: common strings (©nam, ©ART, ©gen, ©day, tvsh, tven, sonm, soar, soal, ©lyr),
    /// ints (tvsn, tves, stik, hdvd, rtng), pair ints (trkn, disk), bool-ish ints (hevc, hdrv, pgap, cpil),
    /// and artwork (covr).
    /// Best-effort: if structure is missing, this call is a no-op.
    static func updateIlst(at url: URL, tags: [String: Any]) throws {
        guard var data = try? Data(contentsOf: url) else { throw AtomCodecError.fileReadFailed }

        guard let moov = findAtom(in: data, type: "moov", start: 0, length: data.count),
              let udta = findAtom(in: data, type: "udta", start: moov.payloadRange.lowerBound, length: moov.payloadRange.count),
              let meta = findAtom(in: data, type: "meta", start: udta.payloadRange.lowerBound, length: udta.payloadRange.count)
        else {
            // Structure missing; skip silently
            return
        }

        // meta starts with 4 bytes (version/flags); ilst follows
        let metaPayloadStart = meta.payloadRange.lowerBound + 4
        let metaPayloadLen = meta.payloadRange.count - 4
        guard metaPayloadLen > 8 else { return }

        // Find existing ilst inside meta payload
        let ilstSearchRange = metaPayloadStart ..< (metaPayloadStart + metaPayloadLen)
        let ilst = findAtom(in: data, type: "ilst", start: ilstSearchRange.lowerBound, length: ilstSearchRange.count)

        let newIlst = buildIlst(tags: tags)
        let oldIlstSize = ilst?.size ?? 0
        let insertionOffset = ilst?.offset ?? ilstSearchRange.lowerBound

        // Replace or insert ilst
        data.replaceSubrange(insertionOffset ..< insertionOffset + oldIlstSize, with: newIlst)

        let delta = newIlst.count - oldIlstSize
        if delta != 0 {
            // Adjust sizes for meta, udta, moov, and file length
            adjustSize(in: &data, at: meta.offset, by: delta)
            adjustSize(in: &data, at: udta.offset, by: delta)
            adjustSize(in: &data, at: moov.offset, by: delta)
        }

        // Write back to file safely
        let tempURL = url.deletingLastPathComponent().appendingPathComponent("\(UUID().uuidString).mp4")
        try data.write(to: tempURL, options: .atomic)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }

    internal static func buildIlst(tags: [String: Any]) -> Data {
        var children = Data()
        if let title = tags["©nam"] as? String {
            children.append(makeDataAtom(fourcc: "©nam", value: title))
        }
        if let artist = tags["©ART"] as? String {
            children.append(makeDataAtom(fourcc: "©ART", value: artist))
        }
        if let genre = tags["©gen"] as? String {
            children.append(makeDataAtom(fourcc: "©gen", value: genre))
        }
        if let day = tags["©day"] as? String {
            children.append(makeDataAtom(fourcc: "©day", value: day))
        }
        if let lyrics = tags["©lyr"] as? String {
            children.append(makeDataAtom(fourcc: "©lyr", value: lyrics))
        }
        if let show = tags["tvsh"] as? String {
            children.append(makeDataAtom(fourcc: "tvsh", value: show))
        }
        if let episodeID = tags["tven"] as? String {
            children.append(makeDataAtom(fourcc: "tven", value: episodeID))
        }
        if let sortName = tags["sonm"] as? String {
            children.append(makeDataAtom(fourcc: "sonm", value: sortName))
        }
        if let sortArtist = tags["soar"] as? String {
            children.append(makeDataAtom(fourcc: "soar", value: sortArtist))
        }
        if let sortAlbum = tags["soal"] as? String {
            children.append(makeDataAtom(fourcc: "soal", value: sortAlbum))
        }
        if let season = tags["tvsn"] as? Int {
            children.append(makeIntAtom(fourcc: "tvsn", value: season))
        }
        if let episode = tags["tves"] as? Int {
            children.append(makeIntAtom(fourcc: "tves", value: episode))
        }
        if let mediaKind = tags["stik"] as? Int {
            children.append(makeIntAtom(fourcc: "stik", value: mediaKind))
        }
        if let hd = tags["hdvd"] as? Int {
            children.append(makeIntAtom(fourcc: "hdvd", value: hd))
        }
        if let hevc = tags["hevc"] as? Int {
            children.append(makeIntAtom(fourcc: "hevc", value: hevc))
        }
        if let hdr = tags["hdrv"] as? Int {
            children.append(makeIntAtom(fourcc: "hdrv", value: hdr))
        }
        if let advisory = tags["rtng"] as? Int {
            children.append(makeIntAtom(fourcc: "rtng", value: advisory))
        }
        if let gapless = tags["pgap"] as? Int {
            children.append(makeIntAtom(fourcc: "pgap", value: gapless))
        }
        if let compilation = tags["cpil"] as? Int {
            children.append(makeIntAtom(fourcc: "cpil", value: compilation))
        }
        if let track = tags["trkn"] as? [Int], track.count >= 2 {
            children.append(makePairAtom(fourcc: "trkn", a: track[0], b: track[1]))
        }
        if let disc = tags["disk"] as? [Int], disc.count >= 2 {
            children.append(makePairAtom(fourcc: "disk", a: disc[0], b: disc[1]))
        }
        if let cover = tags["covr"] as? Data {
            children.append(makeDataAtom(fourcc: "covr", data: cover, dataType: 13)) // JPEG/PNG
        }

        var ilst = Data()
        let size = UInt32(children.count + 8)
        ilst.append(size.bigEndianData)
        ilst.append(fourCC("ilst"))
        ilst.append(children)
        return ilst
    }

    private static func makeDataAtom(fourcc: String, value: String) -> Data {
        let utf8 = Data(value.utf8)
        return makeDataAtom(fourcc: fourcc, data: utf8, dataType: 1)
    }

    private static func makeIntAtom(fourcc: String, value: Int) -> Data {
        var bytes = Data()
        bytes.append(UInt32(value).bigEndianData)
        return makeDataAtom(fourcc: fourcc, data: bytes, dataType: 21)
    }

    private static func makePairAtom(fourcc: String, a: Int, b: Int) -> Data {
        var bytes = Data()
        bytes.append(UInt16(0).bigEndianData) // placeholder
        bytes.append(UInt16(a).bigEndianData)
        bytes.append(UInt16(b).bigEndianData)
        bytes.append(UInt16(0).bigEndianData)
        return makeDataAtom(fourcc: fourcc, data: bytes, dataType: 0)
    }

    private static func makeDataAtom(fourcc: String, data: Data, dataType: UInt32) -> Data {
        var inner = Data()
        // data atom: size + 'data' + type(4 bytes) + locale(4 bytes) + payload
        let dataSize = UInt32(16 + data.count)
        inner.append(dataSize.bigEndianData)
        inner.append(fourCC("data"))
        inner.append(dataType.bigEndianData) // type
        inner.append(UInt32(0).bigEndianData) // locale/reserved
        inner.append(data)

        var outer = Data()
        let outerSize = UInt32(inner.count + 8)
        outer.append(outerSize.bigEndianData)
        outer.append(fourCC(fourcc))
        outer.append(inner)
        return outer
    }

    public static func findAtom(in data: Data, type: String, start: Int, length: Int) -> Atom? {
        var offset = start
        let end = start + length
        while offset + 8 <= end {
            guard let size = readUInt32(data, offset),
                  size >= 8,
                  let t = readType(data, offset + 4)
            else { return nil }
            let intSize = Int(size)
            let next = offset + intSize
            if next > end { return nil }
            if t == type {
                let payloadRange = (offset + 8) ..< next
                return Atom(offset: offset, size: intSize, type: t, payloadRange: payloadRange)
            }
            offset = next
        }
        return nil
    }

    static func adjustSize(in data: inout Data, at offset: Int, by delta: Int) {
        guard let size = readUInt32(data, offset) else { return }
        let newSize = UInt32(Int(size) + delta)
        data.replaceSubrange(offset ..< offset + 4, with: newSize.bigEndianData)
    }

    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        return data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }

    private static func readType(_ data: Data, _ offset: Int) -> String? {
        guard offset + 4 <= data.count else { return nil }
        let slice = data[offset..<offset+4]
        return String(bytes: slice, encoding: .ascii)
    }

    static func fourCC(_ s: String) -> Data {
        var d = Data(count: 4)
        let bytes = Array(s.utf8.prefix(4))
        for i in 0..<min(4, bytes.count) { d[i] = bytes[i] }
        return d
    }
    
    /// Read ilst atom and extract all metadata tags
    /// Returns a dictionary mapping fourCC codes to their values (String, Int, or Data)
    public static func readIlst(from url: URL) throws -> [String: Any] {
        guard let data = try? Data(contentsOf: url) else {
            throw AtomCodecError.fileReadFailed
        }
        
        // Find moov -> udta -> meta -> ilst structure
        guard let moov = findAtom(in: data, type: "moov", start: 0, length: data.count),
              let udta = findAtom(in: data, type: "udta", start: moov.payloadRange.lowerBound, length: moov.payloadRange.count),
              let meta = findAtom(in: data, type: "meta", start: udta.payloadRange.lowerBound, length: udta.payloadRange.count)
        else {
            // Structure missing - return empty dict (not an error, file may not have metadata)
            return [:]
        }
        
        // meta starts with 4 bytes (version/flags); ilst follows
        let metaPayloadStart = meta.payloadRange.lowerBound + 4
        let metaPayloadLen = meta.payloadRange.count - 4
        guard metaPayloadLen > 8 else { return [:] }
        
        // Find ilst inside meta payload
        let ilstSearchRange = metaPayloadStart ..< (metaPayloadStart + metaPayloadLen)
        guard let ilst = findAtom(in: data, type: "ilst", start: ilstSearchRange.lowerBound, length: ilstSearchRange.count) else {
            return [:]
        }
        
        // Parse all child atoms in ilst
        var tags: [String: Any] = [:]
        var offset = ilst.payloadRange.lowerBound
        let end = ilst.payloadRange.upperBound
        
        // Safety limit to prevent infinite loops on malformed files
        let maxIterations = 10000
        var iterations = 0
        
        while offset + 8 <= end && iterations < maxIterations {
            iterations += 1
            
            guard let atomSize = readUInt32(data, offset),
                  atomSize >= 8,
                  atomSize <= UInt32(end - offset), // Ensure atom doesn't extend beyond ilst
                  let fourCC = readType(data, offset + 4) else {
                break // Malformed atom, stop parsing
            }
            
            let intSize = Int(atomSize)
            
            // Validate atom doesn't extend beyond bounds
            guard offset + intSize <= end,
                  offset + intSize <= data.count else {
                break // Atom extends beyond ilst or file
            }
            
            // Parse the data atom inside
            let atomPayloadStart = offset + 8
            let atomPayloadEnd = offset + intSize
            
            // Only parse if we have a valid fourCC (not empty or invalid)
            if !fourCC.isEmpty && fourCC.count == 4 {
                if let value = parseDataAtom(in: data, start: atomPayloadStart, end: atomPayloadEnd) {
                    // Only store non-nil, non-empty values
                    if let stringValue = value as? String, !stringValue.isEmpty {
                        tags[fourCC] = value
                    } else if value is Int32 || value is [Int] || value is Data {
                        tags[fourCC] = value
                    }
                }
            }
            
            offset += intSize
        }
        
        return tags
    }
    
    /// Parse a data atom (e.g., "©nam", "tvsh", "tvsn") and extract its value
    /// Structure: size(4) + "data"(4) + type(4) + locale(4) + payload
    private static func parseDataAtom(in data: Data, start: Int, end: Int) -> Any? {
        guard start + 16 <= end else { return nil }
        
        // Read inner "data" atom
        guard let dataAtomSize = readUInt32(data, start),
              dataAtomSize >= 16,
              dataAtomSize <= UInt32(end - start), // Ensure atom doesn't extend beyond bounds
              let dataType = readType(data, start + 4),
              dataType == "data" else {
            return nil
        }
        
        // Read data type (4 bytes after "data")
        let typeOffset = start + 8
        guard typeOffset + 4 <= end,
              let dataTypeValue = readUInt32(data, typeOffset) else {
            return nil
        }
        
        // Skip locale (4 bytes)
        let payloadStart = start + 16
        let payloadEnd = start + Int(dataAtomSize)
        
        // Validate payload bounds
        guard payloadStart <= payloadEnd,
              payloadEnd <= end,
              payloadStart < data.count,
              payloadEnd <= data.count else {
            return nil
        }
        
        // Handle empty payload
        guard payloadStart < payloadEnd else {
            return nil
        }
        
        let payload = data.subdata(in: payloadStart..<payloadEnd)
        
        // Parse based on data type
        switch dataTypeValue {
        case 1: // UTF-8 string
            guard !payload.isEmpty else { return nil }
            let string = String(data: payload, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return string?.isEmpty == false ? string : nil // Return nil for empty strings
        case 21: // Signed integer (big-endian)
            guard payload.count >= 4 else { return nil }
            return payload.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Int32? in
                guard bytes.count >= 4 else { return nil }
                return Int32(bigEndian: bytes.load(as: Int32.self))
            }
        case 0: // Pair (for trkn, disk)
            guard payload.count >= 8 else { return nil }
            return payload.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [Int]? in
                guard bytes.count >= 8 else { return nil }
                let a = UInt16(bigEndian: bytes.load(fromByteOffset: 2, as: UInt16.self))
                let b = UInt16(bigEndian: bytes.load(fromByteOffset: 4, as: UInt16.self))
                return [Int(a), Int(b)]
            }
        case 13, 14: // JPEG/PNG image data
            guard !payload.isEmpty else { return nil }
            return payload
        default:
            // Unknown type, try to parse as string as fallback
            guard !payload.isEmpty else { return nil }
            return String(data: payload, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

extension UInt32 {
    var bigEndianData: Data {
        var be = self.bigEndian
        return Data(bytes: &be, count: MemoryLayout<UInt32>.size)
    }
}

extension UInt16 {
    var bigEndianData: Data {
        var be = self.bigEndian
        return Data(bytes: &be, count: MemoryLayout<UInt16>.size)
    }
}

