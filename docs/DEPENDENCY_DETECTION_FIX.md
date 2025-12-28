# Dependency Detection Fix

## Problem
FFmpeg and Tesseract were installed on the system but the app was not detecting them as installed.

## Root Causes

### 1. PATH Environment Variable Not Set
- When running `Process` in macOS, it doesn't automatically inherit the user's shell PATH
- Homebrew installs to `/opt/homebrew/bin` (Apple Silicon) or `/usr/local/bin` (Intel)
- The `which` command couldn't find tools because PATH wasn't set correctly

### 2. FFmpeg Version Output to stderr
- FFmpeg outputs version information to stderr, not stdout
- The original code only read from stdout, missing FFmpeg's version output
- This caused FFmpeg to appear as "installed but version unknown" or "missing"

### 3. Insufficient Path Checking
- Only relied on `which` command
- Didn't check common Homebrew installation paths directly

## Solution

### Enhanced `findCommand()` Method
1. **Direct Path Checking**: First checks common Homebrew paths directly:
   - `/opt/homebrew/bin` (Apple Silicon)
   - `/usr/local/bin` (Intel)
   - Formula-specific paths
   - Standard system paths

2. **Environment Setup**: Sets proper PATH when using `which`:
   - Includes Homebrew paths
   - Preserves existing PATH
   - Falls back to standard paths if PATH not set

3. **File Existence Verification**: Verifies the found path actually exists before returning it

### Enhanced `getVersion()` Method
1. **Reads Both stdout and stderr**: 
   - FFmpeg outputs to stderr
   - Tesseract outputs to stdout
   - Combines both for maximum compatibility

2. **Better Version Extraction**:
   - Uses regex pattern matching (if provided)
   - Falls back to version number extraction
   - Handles multi-line output correctly

3. **Environment Setup**: Sets proper PATH for subprocess execution

## Code Changes

### Before
```swift
private func findCommand(_ command: String) async -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = [command]
    // No PATH setup, only reads stdout
}
```

### After
```swift
private func findCommand(_ command: String) async -> String? {
    // Check common paths first
    let commonPaths = [
        "/opt/homebrew/bin",      // Apple Silicon
        "/usr/local/bin",         // Intel
        // ... more paths
    ]
    
    for basePath in commonPaths {
        let fullPath = "\(basePath)/\(command)"
        if FileManager.default.fileExists(atPath: fullPath) {
            return fullPath
        }
    }
    
    // Fallback with proper PATH
    process.environment = environmentWithHomebrewPaths()
    // ...
}
```

### Version Detection
```swift
// Now reads both stdout AND stderr
let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

// Combine both for FFmpeg compatibility
var output = ""
if let outputString = String(data: outputData, encoding: .utf8) {
    output = outputString
}
if let errorString = String(data: errorData, encoding: .utf8) {
    output = output.isEmpty ? errorString : output + "\n" + errorString
}
```

## Testing

To verify the fix works:

1. **Check FFmpeg**:
   ```bash
   which ffmpeg
   ffmpeg -version 2>&1 | head -1
   ```

2. **Check Tesseract**:
   ```bash
   which tesseract
   tesseract --version
   ```

3. **In App**:
   - Open Dependency Check view
   - Should show both as "Installed" with version numbers
   - FFmpeg: "v8.0.1" (or your version)
   - Tesseract: "v5.5.2" (or your version)

## Common Installation Paths

The fix checks these paths in order:

1. `/opt/homebrew/bin` - Apple Silicon Homebrew (most common on M1/M2/M3 Macs)
2. `/usr/local/bin` - Intel Homebrew or older installations
3. `/opt/homebrew/opt/ffmpeg/bin` - Formula-specific path
4. `/usr/local/opt/ffmpeg/bin` - Formula-specific path (Intel)
5. `/usr/bin` - System binaries
6. `/bin` - Core system binaries

## Future Improvements

1. **User-configurable paths**: Allow users to specify custom installation paths
2. **Version comparison**: Compare detected versions against minimum required versions
3. **Auto-update detection**: Check if newer versions are available
4. **Multiple installation detection**: Handle cases where tools are installed in multiple locations

## Related Files

- `App/Controllers/DependencyChecker.swift` - Main detection logic
- `App/Controllers/DependencyManager.swift` - State management
- `App/Views/DependencyCheckView.swift` - UI display
- `App/Models/DependencyStatus.swift` - Data models

