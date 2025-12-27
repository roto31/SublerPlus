# SublerPlus Version 0.3.0b Release Notes

**Release Date:** December 2024

## Overview

SublerPlus 0.3.0b introduces major enhancements to metadata management with drag-and-drop functionality and comprehensive TV show metadata extraction from MP4 files.

## Major Features

### Drag-and-Drop Metadata Search and Apply

A complete workflow enhancement that allows users to:

- **Drop Files Directly**: Drag and drop media files onto the Advanced Search pane
- **Automatic Metadata Extraction**: Instantly reads and displays existing metadata from files
- **Sidebar Display**: New resizable sidebar showing:
  - File name and embedded artwork
  - Title, studio, year, performers
  - Synopsis and TV show information
- **Auto-Populate Search**: Automatically fills search fields from file metadata
- **Enhanced Results**: Selectable results with detailed metadata preview
- **Apply Workflow**: Confirmation dialog and seamless artwork selection

### TV Show Metadata Extraction from MP4 Atoms

Direct parsing of MP4 metadata atoms to extract:

- **TV Show Name** (tvsh atom)
- **Season Number** (tvsn atom)
- **Episode Number** (tves atom)
- **Episode ID** (tven atom)
- **Content Rating** (rtng atom)

This enhancement allows SublerPlus to read TV show metadata that isn't available through standard AVFoundation APIs.

## Technical Improvements

- **AtomCodec Enhancement**: New `readIlst` method for parsing MP4 metadata atoms
- **Data Atom Parser**: Comprehensive parser supporting strings, integers, pairs, and image data
- **Robust Error Handling**: Graceful fallback to AVFoundation if atom parsing fails
- **Edge Case Handling**: Comprehensive bounds checking and malformed atom handling

## Documentation

### New Documentation

- **How-To Guide** (`docs/HOW_TO_GUIDE.md`): Comprehensive step-by-step guide covering:
  - Getting started and installation
  - Basic and advanced operations
  - Metadata management
  - Muxing and remuxing
  - Subtitle management
  - Troubleshooting section with common issues
  - Tips and best practices

- **Wiki Documentation** (`wiki/How-To-Guide.md`): Summary version for GitHub wiki

### Updated Documentation

- **CHANGELOG.md**: Complete version history with 0.3.0b details
- **README.md**: Updated with new documentation links

## Bug Fixes

- Fixed compilation errors for non-existent AVMetadataIdentifier constants
- Improved metadata extraction reliability
- Enhanced file type validation
- Better error messages for unsupported file types

## Version Information

- **Version**: 0.3.0b
- **Base Version**: Updated from 0.2.0 to 0.3.0 in build script
- **Build System**: Semantic versioning with auto-incrementing beta numbers

## Migration Notes

No breaking changes. This is a feature release that maintains backward compatibility.

## Next Steps

To use the new features:

1. Update to version 0.3.0b
2. Review the How-To Guide for drag-and-drop workflow
3. Try dropping a file onto the Advanced Search pane
4. Explore TV show metadata extraction with files that have embedded metadata

## Support

For issues, questions, or contributions:

- Review the How-To Guide: `docs/HOW_TO_GUIDE.md`
- Check Troubleshooting: `docs/TROUBLESHOOTING.md`
- Create GitHub issues for bugs or feature requests

---

**Full Changelog**: See [CHANGELOG.md](CHANGELOG.md) for complete version history.

