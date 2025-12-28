# File Logging System

## Overview

SublerPlus includes a streaming file logger that writes application logs to a file in the project folder. This allows for easy debugging and monitoring of application behavior.

## Location

Log files are stored in:
- **Project folder**: `logs/sublerplus.log` (when running from project directory)
- **Fallback**: `~/Library/Application Support/SublerPlus/logs/sublerplus.log` (when running as app bundle)

The logger automatically detects the project root by looking for `Package.swift` or `.git` directory.

## Features

### Automatic Log Rotation
- **Max file size**: 10MB (configurable)
- **Backup files**: Up to 5 rotated log files (configurable)
- **Rotation pattern**: `sublerplus.log`, `sublerplus.log.1`, `sublerplus.log.2`, etc.

### Log Format
Each log entry includes:
```
[ISO8601-Timestamp] [LEVEL] [CATEGORY] Message
```

Example:
```
[2025-12-27T21:15:30Z] [INFO] [general] SublerPlus application started
[2025-12-27T21:15:31Z] [ERROR] [network] Failed to connect to API
```

### Categories
- `general` - General application events
- `network` - Network operations
- `providers` - Metadata provider operations
- `pipeline` - Metadata pipeline operations
- `webui` - WebUI server events
- `storage` - Storage/Keychain operations

### Log Levels
- `INFO` - Informational messages
- `ERROR` - Error messages
- `DEBUG` - Debug messages (only when LOG_LEVEL=normal)

## Usage

### Automatic Logging
The file logger is automatically initialized when the app starts. All existing `AppLog.info()` and `AppLog.error()` calls continue to work as before (writing to unified logging).

### Writing to File Logger

#### Option 1: Use File Logger Methods
```swift
// Write to both unified logging and file
AppLog.infoToFile(AppLog.general, "Application started")
AppLog.errorToFile(AppLog.network, "Connection failed")

// Write to file only (debug messages)
AppLog.debugToFile(AppLog.pipeline, "Processing metadata")
```

#### Option 2: Direct File Logger Access
```swift
Task {
    await globalFileLogger.log(level: "INFO", category: "general", message: "Custom message")
}
```

### Explicit Category
```swift
AppLog.infoToFile(AppLog.general, "Message", category: "custom")
```

## Configuration

### Environment Variables
- `LOG_LEVEL=minimal` - Reduces logging (debug messages won't be written)

### Customization
You can create a custom file logger with different settings:

```swift
let customLogger = FileLogger(
    fileName: "custom.log",
    maxFileSize: 5 * 1024 * 1024, // 5MB
    maxBackupFiles: 3
)
```

## Log File Management

### View Logs
```bash
# View current log
tail -f logs/sublerplus.log

# View with timestamps
cat logs/sublerplus.log

# Search logs
grep "ERROR" logs/sublerplus.log
```

### Clear Logs
The log file can be cleared programmatically:
```swift
Task {
    await globalFileLogger.clear()
}
```

### Log Rotation
Logs are automatically rotated when the file size exceeds the maximum:
- Current log: `sublerplus.log`
- Rotated logs: `sublerplus.log.1`, `sublerplus.log.2`, etc.
- Oldest backups are deleted when max backup count is reached

## Security

### Secret Scrubbing
All log messages are automatically scrubbed to remove:
- API keys (`api_key=...`)
- Bearer tokens (`Bearer ...`)
- X-API-Key headers

This ensures sensitive information is not written to log files.

## Thread Safety

The file logger is implemented as an `actor`, ensuring thread-safe access:
- Multiple threads can write simultaneously
- Log entries are written in order
- File operations are serialized

## Performance

- **Asynchronous writing**: Log writes don't block the main thread
- **Buffered I/O**: Uses FileHandle for efficient file operations
- **Lazy initialization**: File handle is created on first write

## Troubleshooting

### Log File Not Created
- Check that the `logs` directory exists and is writable
- Verify file permissions
- Check console for error messages

### Logs Not Appearing
- Ensure you're using `AppLog.infoToFile()` or `AppLog.errorToFile()`
- Regular `AppLog.info()` only writes to unified logging (Console.app)
- Check that `LOG_LEVEL` is not set to `minimal` for debug messages

### Large Log Files
- Log rotation should handle this automatically
- You can manually delete old log files
- Adjust `maxFileSize` and `maxBackupFiles` if needed

## Integration with Existing Logging

The file logger integrates seamlessly with the existing `AppLog` system:
- Existing code continues to work (writes to unified logging)
- New code can use `*ToFile()` methods for file logging
- Both systems can be used simultaneously

---

**Last Updated**: 2025-12-27  
**Version**: 0.3.9b

