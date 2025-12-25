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
    /// Tags supported: ©nam (String), ©ART (String), ©gen (String), ©day (String), covr (Data).
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

    private static func buildIlst(tags: [String: Any]) -> Data {
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

    private static func findAtom(in data: Data, type: String, start: Int, length: Int) -> Atom? {
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

    private static func adjustSize(in data: inout Data, at offset: Int, by delta: Int) {
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

    private static func fourCC(_ s: String) -> Data {
        var d = Data(count: 4)
        let bytes = Array(s.utf8.prefix(4))
        for i in 0..<min(4, bytes.count) { d[i] = bytes[i] }
        return d
    }
}

private extension UInt32 {
    var bigEndianData: Data {
        var be = self.bigEndian
        return Data(bytes: &be, count: MemoryLayout<UInt32>.size)
    }
}

