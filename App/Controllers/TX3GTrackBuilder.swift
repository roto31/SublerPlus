import Foundation
import CoreMedia

/// Builder for TX3G subtitle tracks in MP4 files
/// Creates complete track atom structure: trak -> tkhd, mdia -> mdhd, hdlr, minf -> nmhd, dinf, stbl
public enum TX3GTrackBuilder {
    
    /// Add a TX3G subtitle track to an existing MP4 file
    public static func addTX3GTrack(
        to url: URL,
        samples: [TX3GSample],
        language: String = "eng",
        trackID: UInt32 = 1,
        timescale: UInt32 = 600,
        style: SubtitleStyle = .default
    ) throws {
        guard var fileData = try? Data(contentsOf: url) else {
            throw TX3GError.invalidInput
        }
        
        // Find moov atom
        guard let moov = AtomCodec.findAtom(in: fileData, type: "moov", start: 0, length: fileData.count) else {
            throw TX3GError.encodingFailed
        }
        
        // Build the complete track atom
        let trakAtom = buildTrackAtom(
            samples: samples,
            language: language,
            trackID: trackID,
            timescale: timescale,
            style: style
        )
        
        // Insert track before mvex (if present) or at end of moov
        let mvex = AtomCodec.findAtom(in: fileData, type: "mvex", start: moov.payloadRange.lowerBound, length: moov.payloadRange.count)
        let insertionPoint = mvex?.offset ?? moov.payloadRange.upperBound
        
        // Insert the track
        fileData.insert(contentsOf: trakAtom, at: insertionPoint)
        
        // Adjust moov size
        let delta = trakAtom.count
        AtomCodec.adjustSize(in: &fileData, at: moov.offset, by: delta)
        
        // Adjust file size (ftyp size if present, or add ftyp)
        if AtomCodec.findAtom(in: fileData, type: "ftyp", start: 0, length: 32) != nil {
            // File size is typically in the first 4 bytes if > 4GB, or implicit
            // For simplicity, we'll update the first 4 bytes if it's a size field
        }
        
        // Write back
        let tempURL = url.deletingLastPathComponent().appendingPathComponent("\(UUID().uuidString).mp4")
        try fileData.write(to: tempURL, options: .atomic)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }
    
    /// Build a complete track atom (trak) containing TX3G subtitle track
    private static func buildTrackAtom(
        samples: [TX3GSample],
        language: String,
        trackID: UInt32,
        timescale: UInt32,
        style: SubtitleStyle = .default
    ) -> Data {
        var trak = Data()
        
        // Build tkhd (track header)
        let tkhd = buildTkhd(trackID: trackID)
        
        // Build mdia (media)
        let mdia = buildMdia(samples: samples, language: language, trackID: trackID, timescale: timescale, style: style)
        
        // Combine into trak
        let trakSize = UInt32(8 + tkhd.count + mdia.count)
        trak.append(trakSize.bigEndianData)
        trak.append(AtomCodec.fourCC("trak"))
        trak.append(tkhd)
        trak.append(mdia)
        
        return trak
    }
    
    /// Build tkhd (track header) atom
    private static func buildTkhd(trackID: UInt32) -> Data {
        var tkhd = Data()
        // tkhd: size(4) + type(4) + version/flags(4) + creation(8) + modification(8) + trackID(4) + reserved(4) + duration(8) + reserved(8) + layer(2) + alternate(2) + volume(2) + reserved(2) + matrix(36) + width(4) + height(4)
        let size: UInt32 = 92 // Full tkhd size
        tkhd.append(size.bigEndianData)
        tkhd.append(AtomCodec.fourCC("tkhd"))
        tkhd.append(UInt32(0).bigEndianData) // version(1) + flags(3) = 0x00000001 (track enabled)
        tkhd.append(UInt64(0).bigEndianData) // creation time
        tkhd.append(UInt64(0).bigEndianData) // modification time
        tkhd.append(trackID.bigEndianData) // track ID
        tkhd.append(UInt32(0).bigEndianData) // reserved
        tkhd.append(UInt64(0).bigEndianData) // duration (will be set from samples)
        tkhd.append(UInt64(0).bigEndianData) // reserved
        tkhd.append(UInt16(0).bigEndianData) // layer
        tkhd.append(UInt16(0).bigEndianData) // alternate group
        tkhd.append(UInt16(0).bigEndianData) // volume (0 for text)
        tkhd.append(UInt16(0).bigEndianData) // reserved
        // Matrix (identity)
        tkhd.append(identityMatrix())
        tkhd.append(UInt32(0).bigEndianData) // width (fixed point 16.16)
        tkhd.append(UInt32(0).bigEndianData) // height (fixed point 16.16)
        
        return tkhd
    }
    
    /// Build mdia (media) atom
    private static func buildMdia(
        samples: [TX3GSample],
        language: String,
        trackID: UInt32,
        timescale: UInt32,
        style: SubtitleStyle = .default
    ) -> Data {
        var mdia = Data()
        
        // mdhd (media header)
        let duration = samples.last.map { $0.startTime + $0.duration } ?? CMTime.zero
        let durationInTimescale = UInt64(CMTimeGetSeconds(duration) * Double(timescale))
        let mdhd = buildMdhd(timescale: timescale, duration: durationInTimescale, language: language)
        
        // hdlr (handler)
        let hdlr = buildHdlr()
        
        // minf (media information)
        let minf = buildMinf(samples: samples, timescale: timescale, style: style)
        
        // Combine
        let mdiaSize = UInt32(8 + mdhd.count + hdlr.count + minf.count)
        mdia.append(mdiaSize.bigEndianData)
        mdia.append(AtomCodec.fourCC("mdia"))
        mdia.append(mdhd)
        mdia.append(hdlr)
        mdia.append(minf)
        
        return mdia
    }
    
    /// Build mdhd (media header) atom
    private static func buildMdhd(timescale: UInt32, duration: UInt64, language: String) -> Data {
        var mdhd = Data()
        // mdhd: size(4) + type(4) + version/flags(4) + creation(8) + modification(8) + timescale(4) + duration(8) + language(2) + quality(2)
        let size: UInt32 = 32
        mdhd.append(size.bigEndianData)
        mdhd.append(AtomCodec.fourCC("mdhd"))
        mdhd.append(UInt32(0).bigEndianData) // version(1) + flags(3)
        mdhd.append(UInt64(0).bigEndianData) // creation
        mdhd.append(UInt64(0).bigEndianData) // modification
        mdhd.append(timescale.bigEndianData) // timescale
        mdhd.append(duration.bigEndianData) // duration
        mdhd.append(languageCode(language).bigEndianData) // language (ISO 639-2)
        mdhd.append(UInt16(0).bigEndianData) // quality
        
        return mdhd
    }
    
    /// Build hdlr (handler) atom for text track
    private static func buildHdlr() -> Data {
        var hdlr = Data()
        // hdlr: size(4) + type(4) + version/flags(4) + component type(4) + component subtype(4) + component manufacturer(4) + component flags(4) + component flags mask(4) + component name
        let componentName = "SubtitleHandler"
        let nameData = componentName.data(using: .utf8) ?? Data()
        let size = UInt32(8 + 4 + 4 + 4 + 4 + 4 + 4 + 4 + nameData.count + 1) // +1 for null terminator
        hdlr.append(size.bigEndianData)
        hdlr.append(AtomCodec.fourCC("hdlr"))
        hdlr.append(UInt32(0).bigEndianData) // version + flags
        hdlr.append(AtomCodec.fourCC("mhlr")) // component type: media handler
        hdlr.append(AtomCodec.fourCC("text")) // component subtype: text
        hdlr.append(UInt32(0).bigEndianData) // component manufacturer
        hdlr.append(UInt32(0).bigEndianData) // component flags
        hdlr.append(UInt32(0).bigEndianData) // component flags mask
        hdlr.append(nameData)
        hdlr.append(0) // null terminator
        
        return hdlr
    }
    
    /// Build minf (media information) atom
    private static func buildMinf(samples: [TX3GSample], timescale: UInt32, style: SubtitleStyle = .default) -> Data {
        var minf = Data()
        
        // nmhd (null media header for text)
        let nmhd = buildNmhd()
        
        // dinf (data information)
        let dinf = buildDinf()
        
        // stbl (sample table)
        let stbl = buildStbl(samples: samples, timescale: timescale, style: style)
        
        // Combine
        let minfSize = UInt32(8 + nmhd.count + dinf.count + stbl.count)
        minf.append(minfSize.bigEndianData)
        minf.append(AtomCodec.fourCC("minf"))
        minf.append(nmhd)
        minf.append(dinf)
        minf.append(stbl)
        
        return minf
    }
    
    /// Build nmhd (null media header) atom
    private static func buildNmhd() -> Data {
        var nmhd = Data()
        let size: UInt32 = 12
        nmhd.append(size.bigEndianData)
        nmhd.append(AtomCodec.fourCC("nmhd"))
        nmhd.append(UInt32(0).bigEndianData) // version + flags
        return nmhd
    }
    
    /// Build dinf (data information) atom
    private static func buildDinf() -> Data {
        var dinf = Data()
        
        // dref (data reference)
        var dref = Data()
        let drefSize: UInt32 = 28 // size + type + version/flags + entry count + url entry
        dref.append(drefSize.bigEndianData)
        dref.append(AtomCodec.fourCC("dref"))
        dref.append(UInt32(0).bigEndianData) // version + flags
        dref.append(UInt32(1).bigEndianData) // entry count
        
        // url entry
        var url = Data()
        let urlSize: UInt32 = 12
        url.append(urlSize.bigEndianData)
        url.append(AtomCodec.fourCC("url "))
        url.append(UInt32(0x00000001).bigEndianData) // flags: self-contained
        dref.append(url)
        
        let dinfSize = UInt32(8 + dref.count)
        dinf.append(dinfSize.bigEndianData)
        dinf.append(AtomCodec.fourCC("dinf"))
        dinf.append(dref)
        
        return dinf
    }
    
    /// Build stbl (sample table) atom
    private static func buildStbl(samples: [TX3GSample], timescale: UInt32, style: SubtitleStyle = .default) -> Data {
        var stbl = Data()
        
        // stsd (sample description) with tx3g entry
        let stsd = buildStsd(style: style)
        
        // stts (time-to-sample)
        let stts = buildStts(samples: samples, timescale: timescale)
        
        // stsc (sample-to-chunk)
        let stsc = buildStsc(sampleCount: samples.count)
        
        // stsz (sample size)
        let stsz = buildStsz(samples: samples)
        
        // stco (chunk offset)
        let stco = buildStco(samples: samples)
        
        // Combine
        let stblSize = UInt32(8 + stsd.count + stts.count + stsc.count + stsz.count + stco.count)
        stbl.append(stblSize.bigEndianData)
        stbl.append(AtomCodec.fourCC("stbl"))
        stbl.append(stsd)
        stbl.append(stts)
        stbl.append(stsc)
        stbl.append(stsz)
        stbl.append(stco)
        
        return stbl
    }
    
    /// Build stsd (sample description) atom with TX3G entry
    private static func buildStsd(style: SubtitleStyle = .default) -> Data {
        var stsd = Data()
        
        // TX3G sample entry
        var tx3g = Data()
        // tx3g: size(4) + type(4) + reserved(6) + data reference index(2) + display flags(4) + horizontal justification(1) + vertical justification(1) + background color(6) + text box(8) + style(12) + font name
        let fontData = style.fontName.data(using: .utf8) ?? Data()
        let baseSize: UInt32 = 8 + 6 + 2 + 4 + 1 + 1 + 6 + 8 + 12
        let fontSize = UInt32(fontData.count + 1)
        let tx3gSize = baseSize + fontSize
        tx3g.append(tx3gSize.bigEndianData)
        tx3g.append(AtomCodec.fourCC("tx3g"))
        tx3g.append(Data(count: 6)) // reserved
        tx3g.append(UInt16(1).bigEndianData) // data reference index
        tx3g.append(UInt32(0).bigEndianData) // display flags
        tx3g.append(style.horizontalJustification.rawValue) // horizontal justification
        // Vertical justification: -1 (top), 0 (center), 1 (bottom) -> stored as signed byte
        var vJust = Int8(style.verticalJustification.rawValue)
        tx3g.append(Data(bytes: &vJust, count: 1))
        // Background color (RGBA, 6 bytes: 2 bytes each for R, G, B, then 2 bytes for alpha)
        var bgColor = Data()
        bgColor.append(UInt16(style.backgroundColor.red).bigEndianData)
        bgColor.append(UInt16(style.backgroundColor.green).bigEndianData)
        bgColor.append(UInt16(style.backgroundColor.blue).bigEndianData)
        bgColor.append(UInt16(style.backgroundColor.alpha).bigEndianData)
        bgColor.append(UInt16(0).bigEndianData) // padding
        tx3g.append(bgColor)
        // Text box
        if let textBox = style.textBox {
            tx3g.append(textBox.top.bigEndianData)
            tx3g.append(textBox.left.bigEndianData)
            tx3g.append(textBox.bottom.bigEndianData)
            tx3g.append(textBox.right.bigEndianData)
        } else {
            tx3g.append(UInt32(0).bigEndianData) // text box top
            tx3g.append(UInt32(0).bigEndianData) // text box left
            tx3g.append(UInt32(0).bigEndianData) // text box bottom
            tx3g.append(UInt32(0).bigEndianData) // text box right
        }
        tx3g.append(UInt16(0).bigEndianData) // start char
        tx3g.append(UInt16(0).bigEndianData) // end char
        tx3g.append(UInt16(0).bigEndianData) // font ID
        tx3g.append(UInt8(0)) // font style flags
        tx3g.append(style.fontSize) // font size
        // Text color (RGBA, 4 bytes: R, G, B, A)
        var textColorData = Data()
        textColorData.append(style.textColor.red)
        textColorData.append(style.textColor.green)
        textColorData.append(style.textColor.blue)
        textColorData.append(style.textColor.alpha)
        tx3g.append(textColorData)
        tx3g.append(fontData)
        tx3g.append(0) // null terminator
        
        let stsdSize = UInt32(8 + 4 + tx3g.count) // +4 for entry count
        stsd.append(stsdSize.bigEndianData)
        stsd.append(AtomCodec.fourCC("stsd"))
        stsd.append(UInt32(0).bigEndianData) // version + flags
        stsd.append(UInt32(1).bigEndianData) // entry count
        stsd.append(tx3g)
        
        return stsd
    }
    
    /// Build stts (time-to-sample) atom
    private static func buildStts(samples: [TX3GSample], timescale: UInt32) -> Data {
        var stts = Data()
        
        // Group consecutive samples with same duration
        var entries: [(sampleCount: UInt32, duration: UInt32)] = []
        var currentDuration: UInt32?
        var currentCount: UInt32 = 0
        
        for sample in samples {
            let duration = UInt32(CMTimeGetSeconds(sample.duration) * Double(timescale))
            if duration == currentDuration {
                currentCount += 1
            } else {
                if let dur = currentDuration {
                    entries.append((currentCount, dur))
                }
                currentDuration = duration
                currentCount = 1
            }
        }
        if let dur = currentDuration {
            entries.append((currentCount, dur))
        }
        
        let sttsSize = UInt32(8 + 4 + entries.count * 8) // +4 for entry count
        stts.append(sttsSize.bigEndianData)
        stts.append(AtomCodec.fourCC("stts"))
        stts.append(UInt32(0).bigEndianData) // version + flags
        stts.append(UInt32(entries.count).bigEndianData) // entry count
        for entry in entries {
            stts.append(entry.sampleCount.bigEndianData)
            stts.append(entry.duration.bigEndianData)
        }
        
        return stts
    }
    
    /// Build stsc (sample-to-chunk) atom
    private static func buildStsc(sampleCount: Int) -> Data {
        var stsc = Data()
        // Single chunk containing all samples
        let stscSize: UInt32 = 20 // size + type + version/flags + entry count + one entry
        stsc.append(stscSize.bigEndianData)
        stsc.append(AtomCodec.fourCC("stsc"))
        stsc.append(UInt32(0).bigEndianData) // version + flags
        stsc.append(UInt32(1).bigEndianData) // entry count
        stsc.append(UInt32(1).bigEndianData) // first chunk
        stsc.append(UInt32(UInt32(sampleCount)).bigEndianData) // samples per chunk
        stsc.append(UInt32(1).bigEndianData) // sample description index
        return stsc
    }
    
    /// Build stsz (sample size) atom
    private static func buildStsz(samples: [TX3GSample]) -> Data {
        var stsz = Data()
        
        // Calculate sample sizes (TX3G sample data)
        var sampleSizes: [UInt32] = []
        
        for sample in samples {
            // TX3G sample format: text length (2 bytes) + text data
            let textData = sample.text.data(using: .utf8) ?? Data()
            let sampleSize = UInt32(2 + textData.count)
            sampleSizes.append(sampleSize)
        }
        
        let stszSize = UInt32(8 + 4 + 4 + sampleSizes.count * 4) // +4 for sample size field, +4 for count
        stsz.append(stszSize.bigEndianData)
        stsz.append(AtomCodec.fourCC("stsz"))
        stsz.append(UInt32(0).bigEndianData) // version + flags
        stsz.append(UInt32(0).bigEndianData) // sample size field (0 = variable)
        stsz.append(UInt32(sampleSizes.count).bigEndianData) // sample count
        for size in sampleSizes {
            stsz.append(size.bigEndianData)
        }
        
        return stsz
    }
    
    /// Build stco (chunk offset) atom
    private static func buildStco(samples: [TX3GSample]) -> Data {
        var stco = Data()
        
        // Calculate chunk offsets
        var offset: UInt32 = 0
        var offsets: [UInt32] = []
        
        for sample in samples {
            offsets.append(offset)
            let textData = sample.text.data(using: .utf8) ?? Data()
            offset += UInt32(2 + textData.count) // sample size
        }
        
        let stcoSize = UInt32(8 + 4 + offsets.count * 4) // +4 for entry count
        stco.append(stcoSize.bigEndianData)
        stco.append(AtomCodec.fourCC("stco"))
        stco.append(UInt32(0).bigEndianData) // version + flags
        stco.append(UInt32(offsets.count).bigEndianData) // entry count
        for off in offsets {
            stco.append(off.bigEndianData)
        }
        
        return stco
    }
    
    /// Convert language code to ISO 639-2 format (packed into 2 bytes)
    private static func languageCode(_ code: String) -> UInt16 {
        let iso639 = code.prefix(3).lowercased()
        var result: UInt16 = 0
        for (index, char) in iso639.enumerated() {
            if index < 3 {
                let value = UInt8(char.asciiValue ?? 0) - 0x60 // a=1, b=2, etc.
                result |= UInt16(value) << (5 * (2 - index))
            }
        }
        return result
    }
    
    /// Create identity matrix (36 bytes)
    private static func identityMatrix() -> Data {
        var matrix = Data(count: 36)
        // Set identity matrix values (fixed point 16.16)
        matrix[0] = 0x00; matrix[1] = 0x01; matrix[2] = 0x00; matrix[3] = 0x00 // 1.0
        matrix[16] = 0x00; matrix[17] = 0x01; matrix[18] = 0x00; matrix[19] = 0x00 // 1.0
        matrix[32] = 0x40; matrix[33] = 0x00; matrix[34] = 0x00; matrix[35] = 0x00 // 16384.0 (1.0 in 16.16)
        return matrix
    }
}

extension UInt64 {
    var bigEndianData: Data {
        var be = self.bigEndian
        return Data(bytes: &be, count: MemoryLayout<UInt64>.size)
    }
}


