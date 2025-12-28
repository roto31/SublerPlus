# Drag-and-Drop Troubleshooting Guide

## Issue: Files Not Dropping or Metadata Not Populating

### Symptoms
- Dragging files from Finder into Advanced Search pane
- Files appear to revert back to original location
- Metadata fields remain empty
- No error messages displayed

### Root Causes and Solutions

#### 1. File Type Not Supported

**Problem**: The file type might not be recognized by SwiftUI's drag-and-drop system.

**Solution**:
- Ensure file has one of these extensions: `.mp4`, `.m4v`, `.m4a`, `.mov`, `.mkv`
- Check file extension is visible in Finder (not hidden)
- Try renaming file to have explicit extension

**Verification**:
- Check status bar message: "Unsupported file type: [ext]"
- Supported types: MP4, M4V, M4A, MOV, MKV

#### 2. File Path Issues

**Problem**: File path might contain special characters or be inaccessible.

**Solution**:
- Avoid files with special characters in path
- Ensure file is on local disk (not network drive)
- Check file permissions (read access required)
- Try moving file to a simpler path (e.g., Desktop)

**Verification**:
- Check status bar: "File not found: [filename]"
- Check status bar: "Error resolving file path"

#### 3. Async Loading Issues

**Problem**: File URL extraction from drag-and-drop is asynchronous and might fail silently.

**Solution**:
- Wait a moment after dropping - processing happens asynchronously
- Check status bar for progress messages
- Try dropping the file again if first attempt fails
- Ensure app window has focus when dropping

**Verification**:
- Status bar should show: "Reading metadata from [filename]..."
- Then: "Metadata loaded from [filename]"

#### 4. File Already Open or Locked

**Problem**: File might be in use by another application.

**Solution**:
- Close file in other applications (QuickTime, VLC, etc.)
- Ensure file is not being written to
- Check file is not read-only

**Verification**:
- Check status bar: "Error loading file: [error message]"

#### 5. App Sandbox Restrictions

**Problem**: App Sandbox might be blocking file access.

**Solution**:
- Grant file access permissions when prompted
- Add file location to App Sandbox exceptions (if needed)
- Check System Preferences > Security & Privacy > Files and Folders

**Verification**:
- macOS should prompt for file access permission
- Check status bar for permission-related errors

### Step-by-Step Troubleshooting

1. **Verify File Format**
   ```
   - Check file extension in Finder
   - Right-click file > Get Info
   - Verify "Kind" shows as a video/audio file
   ```

2. **Test with Simple File**
   ```
   - Use a file with simple name (no special characters)
   - Place file on Desktop
   - Try dragging that file
   ```

3. **Check App Status**
   ```
   - Look at status bar at bottom of app
   - Check for error messages
   - Verify app is responsive (not frozen)
   ```

4. **Verify Drop Target**
   ```
   - Ensure you're dropping on Advanced Search pane
   - Look for drag indicator text: "Drag and drop a media file here..."
   - Border should highlight when dragging over
   ```

5. **Check Console Logs**
   ```
   - Open Console.app
   - Filter for "SublerPlus"
   - Look for error messages during drop
   ```

### Expected Behavior

**Successful Drop**:
1. File is dragged over Advanced Search pane
2. Border highlights (blue accent color)
3. File is dropped
4. Status bar shows: "Reading metadata from [filename]..."
5. Sidebar appears with file metadata
6. Search fields auto-populate
7. Status bar shows: "Metadata loaded from [filename]"

**What Should Appear**:
- **Sidebar**:
  - File name
  - Artwork (if embedded)
  - Title, Studio, Year
  - Performers
  - Synopsis (if available)
  - TV Show info (if applicable)

- **Search Fields** (auto-populated):
  - Title field
  - Studio/Network field
  - Year fields (from/to)
  - Actors/Actresses field

### Common Error Messages

| Error Message | Cause | Solution |
|--------------|-------|----------|
| "Unsupported file type: [ext]" | File extension not supported | Use MP4, M4V, M4A, MOV, or MKV |
| "File not found: [filename]" | File doesn't exist or path invalid | Verify file exists, check path |
| "Only local files are supported" | Dropped a web URL | Use local file only |
| "Could not extract file URL" | Drag-and-drop data format issue | Try dropping again or use file picker |
| "Error loading file: [error]" | File access or format issue | Check file permissions and format |

### Alternative Methods

If drag-and-drop continues to fail:

1. **Use File Picker**:
   - Click "Add Files" in toolbar (⌘N)
   - Select file from dialog
   - Then use Advanced Search with file selected

2. **Manual Entry**:
   - Enter metadata manually in search fields
   - Use Advanced Search without dropping file

3. **Command Line**:
   - Use CLI tool for metadata operations
   - `swift run sublerplus-cli /path/to/file.mp4`

### Technical Details

**How It Works**:
1. SwiftUI's `.onDrop` modifier captures drag events
2. `NSItemProvider` extracts file URL asynchronously
3. File URL is validated (exists, type, permissions)
4. `SublerMP4Handler.readFullMetadata` reads metadata
5. `AtomCodec.readIlst` parses MP4 atoms for TV show info
6. Metadata is displayed in sidebar and search fields

**File URL Extraction**:
- Primary: `loadItem(forTypeIdentifier: "public.file-url")`
- Handles both `URL` and `Data` representations
- Resolves symlinks automatically
- Validates file URL format

### Debugging Tips

1. **Enable Verbose Logging**:
   - Check status stream messages
   - Review activity feed in Jobs section

2. **Test File**:
   - Use a known-good MP4 file
   - File with embedded metadata works best
   - Test with both movies and TV shows

3. **Check File Metadata**:
   - Use `mdls` command in Terminal:
     ```bash
     mdls /path/to/file.mp4
     ```
   - Verify file has metadata atoms

4. **Verify App Permissions**:
   - System Preferences > Security & Privacy
   - Check Full Disk Access (if needed)
   - Check Files and Folders permissions

### Still Not Working?

If drag-and-drop still fails after trying all solutions:

1. **Report Issue**:
   - Note the exact error message
   - Include file type and path
   - Check Console.app for detailed errors
   - Create GitHub issue with details

2. **Workaround**:
   - Use file picker instead of drag-and-drop
   - Manually enter search criteria
   - Use CLI for batch operations

3. **Check System**:
   - macOS version (12.0+ required)
   - App version (0.3.0b+ for drag-and-drop feature)
   - Available disk space
   - File system (APFS recommended)

---

**Last Updated**: Version 0.3.0b
**Related Documentation**: [HOW_TO_GUIDE.md](HOW_TO_GUIDE.md), [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

