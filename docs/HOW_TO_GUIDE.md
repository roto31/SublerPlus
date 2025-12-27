# SublerPlus How-To Guide

## Table of Contents

1. [Getting Started](#getting-started)
2. [Basic Operations](#basic-operations)
3. [Advanced Features](#advanced-features)
4. [Metadata Management](#metadata-management)
5. [Muxing and Remuxing](#muxing-and-remuxing)
6. [Subtitle Management](#subtitle-management)
7. [Troubleshooting](#troubleshooting)
8. [Tips and Best Practices](#tips-and-best-practices)

---

## Getting Started

### Installation

1. **System Requirements**
   - macOS 12.0 or later
   - Swift 5.9+ toolchain
   - Optional: FFmpeg (for advanced codec support)
   - Optional: Tesseract (for bitmap subtitle OCR)

2. **Building the Application**
   ```bash
   # Clone the repository
   git clone <repository-url>
   cd SublerPlus
   
   # Build the application
   swift build
   
   # Run tests
   swift test
   
   # Create release build
   ./scripts/build.sh --release
   ```

3. **Initial Setup**
   - Launch SublerPlus
   - Open Settings (⌘,)
   - Add API keys for metadata providers:
     - ThePornDB (optional, for adult content)
     - TMDB (recommended, for movies and TV shows)
     - TVDB (recommended, for TV shows)
   - Set WebUI token (recommended for security)

### First Launch

1. **Dependency Check**
   - On first launch, the app will check for external dependencies
   - Green dot: Dependency installed and up-to-date
   - Yellow dot: Dependency installed but not current version
   - Red dot: Dependency not installed
   - Install missing dependencies using Homebrew or from official sources

2. **API Key Configuration**
   - Navigate to Settings
   - Enter API keys in the respective fields
   - Keys are stored securely in macOS Keychain
   - Click "Save" to store keys

---

## Basic Operations

### Adding Files

**Method 1: File Picker**
- Click "Add Files" button in toolbar (⌘N)
- Select one or more MP4/M4V/MOV files
- Files are added to the file list

**Method 2: Drag and Drop**
- Drag media files from Finder
- Drop onto the file list area
- Files are automatically added

**Method 3: Folder Monitoring**
- Add watch folders in Settings
- New files in watched folders are automatically detected
- Files are automatically enqueued for processing

### Enriching Metadata

**Single File Enrichment**
1. Select a file from the file list
2. Click "Enrich" button (⌘E) or use toolbar
3. Wait for metadata search to complete
4. If multiple matches found, select the correct one
5. Metadata is automatically applied

**Batch Enrichment**
1. Add multiple files to the file list
2. Files are automatically added to the job queue
3. Monitor progress in the Jobs section
4. Review results and retry failed jobs if needed

### Viewing File Details

1. Select a file from the file list
2. View detailed information in the detail pane:
   - Metadata (title, year, studio, performers, etc.)
   - Track information (video, audio, subtitles)
   - Chapters (if available)
   - Artwork

---

## Advanced Features

### Advanced Search with Drag-and-Drop

**Using Drag-and-Drop Metadata Search**

1. **Drop a File**
   - Navigate to the Advanced Search tab
   - Drag and drop a media file onto the search pane
   - The file's existing metadata is automatically extracted and displayed

2. **Review Extracted Metadata**
   - Check the sidebar for file metadata:
     - File name and artwork
     - Title, studio, year
     - Performers and directors
     - Synopsis (if available)
     - TV show information (if applicable)

3. **Auto-Populated Search Fields**
   - Search fields are automatically filled from file metadata
   - You can modify any field before searching
   - Empty fields are populated; existing values are preserved

4. **Search for Matches**
   - Click "Search" button or press Enter
   - Results appear in the results list
   - Select a result to view full details

5. **Apply Metadata**
   - Review the selected result's details
   - Click "Apply Metadata" button
   - Confirm in the dialog
   - Metadata is written to the file

6. **Select Artwork**
   - After applying metadata, artwork picker appears
   - Search for artwork using the selected result's title
   - Browse and select artwork
   - Click "Use This Artwork" to apply

**Manual Search**

1. Enter search criteria:
   - Title or keywords
   - Studio/Network
   - Year range (from/to)
   - Actors/Actresses
   - Directors/Producers
   - Air date (for TV shows)

2. Select provider preference:
   - Balanced (default)
   - Score-first
   - Year-first

3. Click "Search" or press Enter

4. Select a result and apply metadata

### TV Show Metadata Extraction

SublerPlus can extract TV show metadata directly from MP4 files:

**What Gets Extracted:**
- TV Show name (tvsh atom)
- Season number (tvsn atom)
- Episode number (tves atom)
- Episode ID (tven atom)
- Content rating (rtng atom)

**How It Works:**
1. When you drop a file, the app reads MP4 atoms directly
2. TV show information is extracted from the file's metadata atoms
3. Information is displayed in the sidebar
4. Can be used to auto-populate search fields

**Limitations:**
- Only works if the file already has TV show metadata embedded
- Falls back to AVFoundation metadata if atoms are missing
- Some files may not have TV show metadata in atoms

---

## Metadata Management

### Managing API Keys

**Adding API Keys**
1. Open Settings (⌘,)
2. Navigate to API Keys section
3. Enter keys for desired providers
4. Keys are stored in macOS Keychain
5. Click "Save"

**Key Sources:**
- **ThePornDB**: https://metadataapi.net/
- **TMDB**: https://www.themoviedb.org/settings/api
- **TVDB**: https://thetvdb.com/dashboard/account/apikey
- **OpenSubtitles**: https://www.opensubtitles.com/en/consumers

### Ambiguity Resolution

When multiple metadata matches are found:

1. **Automatic Resolution**
   - App checks cache for previous choices
   - If match found, automatically selects
   - No user interaction needed

2. **Manual Selection**
   - Ambiguity sheet appears
   - Review candidates with:
     - Title and year
     - Studio/Network
     - Match score
   - Select the correct match
   - Choice is remembered for future

3. **Cache Management**
   - Clear ambiguity cache in Settings if needed
   - Cache is stored locally and persists between sessions

### Artwork Management

**Viewing Artwork**
- Artwork appears in file detail view
- Click to view full-size image
- Artwork is cached locally

**Refreshing Artwork**
- Select a file
- Click "Refresh Artwork" in file detail view
- New artwork is fetched and applied

**Selecting Alternate Artwork**
- Use Advanced Search to find matches
- After applying metadata, artwork picker appears
- Browse and select from available artwork
- Apply selected artwork

---

## Muxing and Remuxing

### Using Presets

1. **Select a Preset**
   - Open Muxing view
   - Choose from built-in presets:
     - Passthrough (no conversion)
     - Apple TV
     - iPhone
     - iPad
     - Audio Only
     - Audiobook

2. **Create Custom Preset**
   - Click "New Preset"
   - Configure settings:
     - Video settings (resolution, codec, bitrate)
     - Audio settings (codec, bitrate, mixdown)
     - Subtitle settings (format, styling)
   - Save preset

3. **Apply Preset**
   - Select files to mux
   - Choose preset
   - Configure track selection
   - Start muxing

### Track Selection

1. **Select Tracks**
   - Choose video track
   - Select audio tracks (multiple allowed)
   - Choose subtitle tracks
   - Configure conversion options

2. **Audio Conversion**
   - Convert to AAC or AC3
   - Set bitrate
   - Configure mixdown (stereo, 5.1, etc.)

3. **Subtitle Conversion**
   - Convert to TX3G format
   - Configure styling (font, size, color)
   - Set justification and background

### Preset Import/Export

**Exporting Presets**
1. Open Preset Manager
2. Select preset(s) to export
3. Choose format (JSON or PLIST)
4. Save to file
5. Share with others or backup

**Importing Presets**
1. Open Preset Manager
2. Click "Import Presets"
3. Select JSON or PLIST file
4. Choose conflict resolution:
   - Skip conflicting presets
   - Overwrite existing
   - Rename imported presets
5. Review import results
6. Apply imported presets

---

## Subtitle Management

### Searching for Subtitles

1. **Automatic Lookup**
   - Enable "Auto Subtitle Lookup" in Settings
   - Subtitles are automatically searched after metadata enrichment
   - Best match is automatically downloaded and embedded

2. **Manual Search**
   - Select a file
   - Open file detail view
   - Click "Search Subtitles" button
   - Review candidates with:
     - Language
     - Match score
     - Release year
   - Select and download

### Subtitle Configuration

**Default Language**
- Set in Settings
- Default: "eng" (English)
- Used for automatic lookup

**Subtitle Format**
- Subtitles are converted to TX3G format
- Embedded directly in MP4 file
- Compatible with Apple devices

### Subtitle Styling

When converting subtitles:
- Configure font family
- Set font size
- Choose text color
- Set background color
- Configure justification (left, center, right)

---

## Troubleshooting

### Common Issues

#### Files Not Adding

**Problem**: Files don't appear in the file list after adding.

**Solutions**:
- Check file format (MP4, M4V, MOV supported)
- Verify file is not corrupted
- Try adding files one at a time
- Check file permissions

#### Metadata Not Found

**Problem**: No metadata matches found for files.

**Solutions**:
- Verify API keys are set correctly
- Check internet connection
- Try different search terms
- Enable adult content if applicable
- Check provider status (TMDB, TVDB)

#### Metadata Not Applying

**Problem**: Metadata search succeeds but doesn't apply to file.

**Solutions**:
- Check file permissions (read/write)
- Verify file is not locked
- Check available disk space
- Review error messages in status bar
- Try enriching again

#### Artwork Not Displaying

**Problem**: Artwork doesn't appear or loads slowly.

**Solutions**:
- Check internet connection
- Clear artwork cache in Settings
- Refresh artwork for specific file
- Verify artwork URL is accessible
- Check firewall settings

#### Drag-and-Drop Not Working

**Problem**: Files don't respond to drag-and-drop.

**Solutions**:
- Ensure file format is supported
- Try dropping onto file list instead of search pane
- Check if app has focus
- Restart application
- Verify macOS version (12.0+)

#### TV Show Metadata Not Extracted

**Problem**: TV show info not showing in sidebar.

**Solutions**:
- Verify file has TV show metadata in MP4 atoms
- Check if file is properly formatted MP4
- Try a different file
- Metadata may not be embedded in file

#### Subtitle Search Failing

**Problem**: Subtitle search returns no results.

**Solutions**:
- Verify OpenSubtitles API key is set
- Check internet connection
- Try different search terms
- Check subtitle language setting
- Verify file title matches search

#### Muxing Fails

**Problem**: Muxing operation fails or produces errors.

**Solutions**:
- Check FFmpeg is installed (for advanced codecs)
- Verify source file is not corrupted
- Check available disk space
- Review track selection
- Try different preset
- Check codec compatibility

#### Queue Jobs Failing

**Problem**: Jobs in queue fail repeatedly.

**Solutions**:
- Review error messages in job details
- Check file paths are valid
- Verify API keys are set
- Check internet connection
- Clear queue and retry
- Review job settings

### Error Messages

#### "File not found"
- Verify file path is correct
- Check file hasn't been moved or deleted
- Ensure file permissions allow access

#### "Unsupported file type"
- Only MP4, M4V, M4A, MOV, MKV are supported
- Convert file to supported format
- Check file extension matches content

#### "No provider available"
- Add API keys in Settings
- Enable adult content if needed
- Check provider status

#### "Metadata read failed"
- File may be corrupted
- Try a different file
- Check file permissions
- Verify file format

#### "Artwork download failed"
- Check internet connection
- Verify artwork URL is accessible
- Try refreshing artwork
- Clear artwork cache

### Getting Help

1. **Check Documentation**
   - Review this guide
   - Check technical documentation
   - Review troubleshooting sections

2. **Review Logs**
   - Check status bar for error messages
   - Review activity feed in Jobs section
   - Check console logs (if available)

3. **Report Issues**
   - Create GitHub issue with:
     - Error message
     - Steps to reproduce
     - File information (if applicable)
     - System information

---

## Tips and Best Practices

### Metadata Enrichment

1. **Batch Processing**
   - Add multiple files at once
   - Let queue process automatically
   - Review results after completion

2. **Ambiguity Resolution**
   - Review all candidates before selecting
   - Check year and studio match
   - Verify match score
   - Choices are cached for future

3. **API Key Management**
   - Store keys securely in Keychain
   - Rotate keys periodically
   - Use separate keys for testing

### File Organization

1. **Naming Conventions**
   - Use descriptive file names
   - Include year in filename if possible
   - TV shows: Include season/episode

2. **Folder Structure**
   - Organize by media type
   - Use watch folders for automation
   - Keep source files separate from output

### Performance

1. **Large Batches**
   - Process in smaller batches
   - Monitor queue statistics
   - Pause queue if needed

2. **Network Usage**
   - Batch operations reduce API calls
   - Artwork is cached locally
   - Use local metadata when possible

### Security

1. **WebUI Token**
   - Always set a WebUI token
   - Use strong, unique tokens
   - Rotate tokens periodically

2. **API Keys**
   - Store in Keychain (not plain text)
   - Don't share keys
   - Revoke compromised keys immediately

3. **File Permissions**
   - Review file permissions
   - Don't process sensitive files
   - Use App Sandbox when available

### Workflow Optimization

1. **Presets**
   - Create presets for common tasks
   - Export/import presets for sharing
   - Use presets for consistency

2. **Automation**
   - Use watch folders for automatic processing
   - Enable auto subtitle lookup
   - Configure batch processing

3. **Quality Control**
   - Review metadata before applying
   - Check artwork quality
   - Verify subtitle accuracy
   - Test on target devices

---

## Additional Resources

- **User Guide**: `docs/USER_GUIDE.md`
- **Technical Documentation**: `docs/TECHNICAL.md`
- **Security Guide**: `docs/SECURITY.md`
- **Troubleshooting Guide**: `docs/TROUBLESHOOTING.md`
- **GitHub Wiki**: Check repository wiki for additional documentation

---

## Version Information

This guide is for SublerPlus version 0.3.0b and later.

For version-specific information, see [CHANGELOG.md](../CHANGELOG.md).

