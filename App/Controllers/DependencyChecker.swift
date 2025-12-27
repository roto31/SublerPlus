import Foundation

public enum DependencyCheckError: Error, Equatable {
    case checkFailed(String)
}

public final class DependencyChecker: @unchecked Sendable {
    
    public static let shared = DependencyChecker()
    
    // Define all dependencies
    public static let allDependencies: [DependencyInfo] = [
        DependencyInfo(
            id: "ffmpeg",
            name: "FFmpeg",
            description: "Required for advanced codec support (HEVC, AV1, DTS, Opus, etc.) and audio/video conversion",
            installCommand: "brew install ffmpeg",
            installURL: "https://ffmpeg.org/download.html",
            versionCommand: ["ffmpeg", "-version"],
            versionPattern: "ffmpeg version ([0-9.]+)",
            requiredFeatures: [
                "Advanced video codecs (HEVC, AV1, VVC, VP8, VP9)",
                "Advanced audio codecs (DTS, Opus, Vorbis, FLAC, TrueHD)",
                "Audio conversion (FLAC→AAC, MP3→AAC, etc.)",
                "Subtitle OCR (PGS, VobSub bitmap subtitles)",
                "Codec detection for unsupported formats"
            ]
        ),
        DependencyInfo(
            id: "tesseract",
            name: "Tesseract OCR",
            description: "Optional - Used for OCR-based subtitle conversion from bitmap formats (PGS, VobSub)",
            installCommand: "brew install tesseract",
            installURL: "https://github.com/tesseract-ocr/tesseract",
            versionCommand: ["tesseract", "--version"],
            versionPattern: "tesseract ([0-9.]+)",
            requiredFeatures: [
                "Subtitle OCR (PGS bitmap subtitles)",
                "Subtitle OCR (VobSub bitmap subtitles)"
            ]
        )
    ]
    
    private init() {}
    
    /// Check all dependencies and return their status
    public func checkAllDependencies() async -> DependencyCheckResult {
        var checkedDependencies: [DependencyInfo] = []
        
        for var dependency in Self.allDependencies {
            let status = await checkDependency(dependency)
            dependency.status = status.status
            dependency.installedVersion = status.version
            checkedDependencies.append(dependency)
        }
        
        return DependencyCheckResult(dependencies: checkedDependencies)
    }
    
    /// Check a single dependency
    public func checkDependency(_ dependency: DependencyInfo) async -> (status: DependencyStatus, version: String?) {
        // Check if command exists
        guard let commandPath = await findCommand(dependency.versionCommand[0]) else {
            return (.missing, nil)
        }
        
        // Try to get version
        let version = await getVersion(dependency: dependency, commandPath: commandPath)
        
        if let version = version {
            // Check if version meets requirements (simplified - just check if installed)
            // In a full implementation, we'd compare versions
            if let requiredVersion = dependency.requiredVersion {
                if compareVersions(version, requiredVersion) >= 0 {
                    return (.installed, version)
                } else {
                    return (.outdated, version)
                }
            } else {
                return (.installed, version)
            }
        } else {
            // Command exists but version check failed - assume installed but can't verify
            return (.installed, nil)
        }
    }
    
    /// Find command in PATH
    private func findCommand(_ command: String) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    /// Get version of a dependency
    private func getVersion(dependency: DependencyInfo, commandPath: String) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: commandPath)
        process.arguments = Array(dependency.versionCommand.dropFirst())
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Try to extract version using pattern if provided
                    if let pattern = dependency.versionPattern {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                            let range = NSRange(location: 0, length: output.utf16.count)
                            if let match = regex.firstMatch(in: output, range: range),
                               let versionRange = Range(match.range(at: 1), in: output) {
                                return String(output[versionRange])
                            }
                        }
                    }
                    // Fallback: return first line or first number sequence
                    let lines = output.components(separatedBy: .newlines)
                    if let firstLine = lines.first, !firstLine.isEmpty {
                        // Try to extract version number
                        if let versionMatch = firstLine.range(of: #"\d+\.\d+"#, options: .regularExpression) {
                            return String(firstLine[versionMatch])
                        }
                        return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    /// Compare version strings (simplified)
    private func compareVersions(_ v1: String, _ v2: String) -> Int {
        let v1Parts = v1.components(separatedBy: ".").compactMap { Int($0) }
        let v2Parts = v2.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Parts.count, v2Parts.count)
        for i in 0..<maxLength {
            let v1Part = i < v1Parts.count ? v1Parts[i] : 0
            let v2Part = i < v2Parts.count ? v2Parts[i] : 0
            
            if v1Part > v2Part {
                return 1
            } else if v1Part < v2Part {
                return -1
            }
        }
        
        return 0
    }
    
    /// Check if Homebrew is installed
    public func isHomebrewInstalled() async -> Bool {
        return await findCommand("brew") != nil
    }
    
    /// Get installation instructions for a dependency
    public func getInstallationInstructions(for dependency: DependencyInfo) async -> String {
        var instructions = "To install \(dependency.name):\n\n"
        
        if await isHomebrewInstalled() {
            instructions += "1. Using Homebrew (recommended):\n"
            instructions += "   \(dependency.installCommand)\n\n"
        } else {
            instructions += "1. Install Homebrew first:\n"
            instructions += "   /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n\n"
            instructions += "2. Then install \(dependency.name):\n"
            instructions += "   \(dependency.installCommand)\n\n"
        }
        
        if let url = dependency.installURL {
            instructions += "2. Or download from: \(url)\n"
        }
        
        return instructions
    }
}

