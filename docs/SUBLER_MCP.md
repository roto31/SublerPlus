# Subler MCP Server

## Overview

The Subler MCP Server provides access to the Subler codebase and MP42Foundation framework through the Model Context Protocol. It offers both code search/indexing capabilities and runtime access to MP42Foundation functionality to aid in building SublerPlus.

## Features

- **Code Search**: Search and index the entire Subler codebase (C/C++/Objective-C/Swift)
- **API Reference**: Access MP42Foundation framework API documentation
- **Code Examples**: Extract and search code examples from Subler
- **Runtime Analysis**: Analyze MP4 files using MP42Foundation (read-only operations)
- **Full-Text Search**: Search across class names, functions, and code content
- **Caching**: Local caching of indexes and API references for fast access

## Installation

The Subler MCP server is included in the SublerPlus workspace. Build it with:

```bash
cd SublerMCP
swift build --product SublerMCPExecutable
```

## Configuration

### Basic Configuration

Add to your `mcp.json`:

```json
{
  "mcpServers": {
    "Subler": {
      "type": "stdio",
      "command": "swift",
      "args": [
        "run",
        "--package-path",
        "${workspaceFolder}/SublerMCP",
        "SublerMCPExecutable"
      ],
      "env": {
        "WORKSPACE_FOLDER": "${workspaceFolder}"
      }
    }
  }
}
```

## Available Resources

- `subler://codebase` - List of all indexed files in Subler codebase
- `subler://file/{path}` - Get file contents from Subler codebase
- `subler://api/{class}` - Get API documentation for MP42Foundation class
- `subler://examples/{type}` - Get code examples by type

## Available Tools

### Code Search Tools

#### search_code

Search Subler codebase by query.

**Parameters:**
- `query` (required): Search query string
- `language` (optional): Filter by language (Swift, Objective-C, C, C++)

**Example:**
```
@Subler search_code query="MP42File" language="Objective-C"
```

#### find_class

Find class definitions in Subler codebase.

**Parameters:**
- `className` (required): Class name to find

**Example:**
```
@Subler find_class className="MP42File"
```

#### find_function

Find function definitions in Subler codebase.

**Parameters:**
- `functionName` (required): Function name to find

**Example:**
```
@Subler find_function functionName="initWithURL"
```

#### get_file_contents

Get file contents from Subler codebase.

**Parameters:**
- `filePath` (required): Relative path to file in Subler codebase

**Example:**
```
@Subler get_file_contents filePath="MP42Foundation/MP42/MP42File.h"
```

#### get_api_reference

Get API reference for MP42Foundation class or method.

**Parameters:**
- `className` (required): MP42Foundation class name

**Example:**
```
@Subler get_api_reference className="MP42File"
```

### Runtime Tools

#### analyze_mp4_file

Analyze MP4 file using MP42Foundation (read-only operation).

**Parameters:**
- `filePath` (required): Path to MP4 file

**Example:**
```
@Subler analyze_mp4_file filePath="/path/to/video.mp4"
```

#### get_track_info

Get track information from MP4 file.

**Parameters:**
- `filePath` (required): Path to MP4 file
- `trackID` (optional): Track ID

**Example:**
```
@Subler get_track_info filePath="/path/to/video.mp4" trackID=1
```

#### get_metadata

Extract metadata from MP4 file.

**Parameters:**
- `filePath` (required): Path to MP4 file

**Example:**
```
@Subler get_metadata filePath="/path/to/video.mp4"
```

#### list_supported_codecs

List codecs supported by MP42Foundation.

**Example:**
```
@Subler list_supported_codecs
```

#### test_import

Test file import capabilities (read-only).

**Parameters:**
- `filePath` (required): Path to file to test

**Example:**
```
@Subler test_import filePath="/path/to/video.mp4"
```

## MP42Foundation Framework

### Building the Framework

The MP42Foundation framework must be built before runtime tools can work:

```bash
cd SublerMCP
./scripts/build-mp42foundation.sh
```

This will:
- Compile MP42Foundation from C/C++/Objective-C sources
- Generate framework bundle
- Cache the built framework (skips rebuild if recent)

### Framework Requirements

- Xcode Command Line Tools
- Ability to compile C/C++/Objective-C code
- Subler repository must be present in workspace

## Cache Location

Data is cached in:
- `~/.subler-mcp/index/` - Code index (24 hour expiration)
- `~/.subler-mcp/api-index/` - API reference index (7 day expiration)
- `SublerMCP/build/MP42Foundation/` - Built framework (cached)

## Architecture

The server consists of:
- **SublerStdioServer**: Main MCP protocol handler (JSON-RPC 2.0)
- **SublerCodeIndexer**: Code search and indexing (actor)
- **SublerCodeParser**: Parses C/C++/Objective-C/Swift code (actor)
- **SublerAPIIndex**: Indexes MP42Foundation API surface (actor)
- **CodeExampleExtractor**: Extracts code examples (actor)
- **MP42FoundationBridge**: Runtime bridge to MP42Foundation framework (actor)

## Troubleshooting

### Server Not Starting

1. Verify Swift is installed:
   ```bash
   swift --version
   ```

2. Build the executable:
   ```bash
   cd SublerMCP
   swift build --product SublerMCPExecutable
   ```

3. Verify Subler directory exists:
   ```bash
   ls -la Subler/
   ```

4. Check MCP logs in Cursor AI:
   - Open Output panel: `Cmd+Shift+U` (macOS) or `Ctrl+Shift+U` (Windows/Linux)
   - Select "MCP Logs" from dropdown
   - Look for initialization errors

### MP42Foundation Framework Not Found

**Symptoms:**
- Runtime tools fail with "framework not found" errors

**Solutions:**
1. Build the framework:
   ```bash
   cd SublerMCP
   ./scripts/build-mp42foundation.sh
   ```

2. Verify framework exists:
   ```bash
   ls -la SublerMCP/build/MP42Foundation/MP42Foundation.framework
   ```

3. Check Xcode Command Line Tools:
   ```bash
   xcode-select -p
   ```

### Code Index Not Loading

1. Check cache directory permissions:
   ```bash
   ls -la ~/.subler-mcp/
   ```

2. Clear and rebuild index:
   ```bash
   rm -rf ~/.subler-mcp/index/
   ```

3. Restart the MCP server to rebuild index

### Search Results Not Relevant

1. Rebuild code index:
   ```bash
   rm -rf ~/.subler-mcp/index/
   ```

2. Restart server to trigger re-indexing

3. Verify Subler codebase is accessible

## Security Best Practices

1. **Read-Only Operations**:
   - Runtime tools are read-only by default
   - No file modification operations
   - Safe for analyzing MP4 files

2. **Input Validation**:
   - All file paths are validated
   - Bounds checking on API calls
   - Error handling prevents crashes

3. **Cache Security**:
   - Cache directory is in user home directory
   - No sensitive data is cached
   - Cache can be cleared safely

## Performance Optimization

### Cache Management

- Code index: Cached for 24 hours
- API index: Cached for 7 days
- Framework: Cached until source changes

### Background Operations

- Code indexing happens in background
- API indexing happens asynchronously
- Framework building is cached

## Usage Examples

### Search for MP42File Usage

```
@Subler search_code query="MP42File" language="Objective-C"
```

### Get MP42File API Reference

```
@Subler get_api_reference className="MP42File"
```

### Find Class Definition

```
@Subler find_class className="MP42Track"
```

### Analyze MP4 File

```
@Subler analyze_mp4_file filePath="/path/to/video.mp4"
```

### Get File Contents

```
@Subler get_file_contents filePath="MP42Foundation/MP42/MP42File.h"
```

## Protocol Compliance

- **Protocol Version**: 2024-11-05 (Cursor AI specification)
- **Transport**: stdio (local command-line server)
- **Error Codes**: Full JSON-RPC 2.0 error code support
- **Request Correlation**: All responses include request `id`

## Support

For issues or questions:

1. Check MCP logs in Cursor AI (`Cmd+Shift+U` → "MCP Logs")
2. Review cache directory: `~/.subler-mcp/`
3. Verify Subler directory exists
4. Check framework build status
5. Review documentation in `docs/` directory

