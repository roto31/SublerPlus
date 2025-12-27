import Foundation

/// Wrapper for FFmpeg functionality
/// Uses command-line FFmpeg tools for codec detection and conversion.
/// For production use, consider integrating FFmpegKit Swift package for better performance:
/// https://github.com/arthenica/ffmpeg-kit
public enum FFmpegWrapper {
    
    /// Check if FFmpeg is available
    public static func isAvailable() async -> Bool {
        // Check if ffmpeg command exists via DependencyChecker
        let result = await DependencyChecker.shared.checkAllDependencies()
        if let ffmpegDep = result.dependencies.first(where: { $0.id == "ffmpeg" }) {
            return ffmpegDep.status == .installed
        }
        return false
    }
    
    /// Initialize FFmpeg libraries
    /// This would initialize FFmpeg when using a Swift package wrapper
    public static func initialize() async throws {
        guard await isAvailable() else {
            throw FFmpegError.notAvailable
        }
        // Initialize FFmpeg libraries here when package is added
        // Example: av_register_all() or equivalent initialization
    }
    
    /// Detect codec from file
    public static func detectCodec(at url: URL) async throws -> String? {
        guard await isAvailable() else {
            throw FFmpegError.notAvailable
        }
        
        // Use ffprobe command-line tool to detect codec
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffprobe")
        process.arguments = [
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=codec_name",
            "-of", "default=noprint_wrappers=1:nokey=1",
            url.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let codec = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !codec.isEmpty {
                    return codec
                }
            }
        } catch {
            throw FFmpegError.detectionFailed(error.localizedDescription)
        }
        
        return nil
    }
    
    /// Convert audio file using FFmpeg
    public static func convertAudio(
        input: URL,
        output: URL,
        codec: String,
        bitrate: Int? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        guard await isAvailable() else {
            throw FFmpegError.notAvailable
        }
        
        // Build FFmpeg command
        var args: [String] = [
            "-i", input.path,
            "-c:a", codec
        ]
        
        if let bitrate = bitrate {
            args.append(contentsOf: ["-b:a", "\(bitrate)"])
        }
        
        args.append(contentsOf: [
            "-y", // Overwrite output
            output.path
        ])
        
        // Execute FFmpeg
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw FFmpegError.conversionFailed(errorMsg)
        }
    }
}

public enum FFmpegError: Error, Equatable {
    case notAvailable
    case detectionFailed(String)
    case conversionFailed(String)
}


