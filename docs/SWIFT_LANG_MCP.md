# Swift Language MCP Server

## Overview

The Swift Language MCP Server provides access to Swift language documentation, Standard Library API references, and Swift Evolution proposals through the Model Context Protocol.

## Features

- **Swift Language Documentation**: Search and access Swift.org documentation
- **Standard Library APIs**: Search and reference Swift Standard Library symbols
- **Swift Evolution**: Access Swift Evolution proposals and language changes
- **Code Examples**: Retrieve code examples for Swift topics
- **Caching**: Local caching of parsed documentation for fast access

## Installation

The Swift Lang MCP server is included in the SublerPlus workspace. Build it with:

```bash
cd SwiftLangMCP
swift build --product SwiftLangMCPExecutable
```

## Configuration

Add to your `mcp.json`:

```json
{
  "mcpServers": {
    "Swift Lang": {
      "command": "swift",
      "args": [
        "run",
        "--package-path",
        "${workspaceFolder}/SwiftLangMCP",
        "SwiftLangMCPExecutable"
      ]
    }
  }
}
```

## Available Resources

- `swift://documentation` - Swift language documentation
- `swift://api` - Swift Standard Library API reference
- `swift://evolution` - Swift Evolution proposals

## Available Tools

### search_swift_documentation

Search Swift language documentation.

**Parameters:**
- `query` (required): Search query string
- `category` (optional): Category filter

**Example:**
```
@Swift Lang search_swift_documentation query="async await" category="language"
```

### get_api_reference

Get API documentation for a Swift symbol.

**Parameters:**
- `symbol` (required): Swift API symbol name

**Example:**
```
@Swift Lang get_api_reference symbol="Array"
```

### search_standard_library

Search Swift Standard Library APIs.

**Parameters:**
- `query` (required): Search query

**Example:**
```
@Swift Lang search_standard_library query="String"
```

### get_code_example

Get code examples for a topic.

**Parameters:**
- `topic` (required): Topic or keyword

**Example:**
```
@Swift Lang get_code_example topic="closures"
```

### search_evolution_proposals

Search Swift Evolution proposals.

**Parameters:**
- `query` (required): Search query

**Example:**
```
@Swift Lang search_evolution_proposals query="async"
```

## Cache Location

Documentation cache is stored in:
- `~/.swift-lang-mcp/cache/` - Cached documentation sections
- `~/.swift-lang-mcp/api-index/` - API index cache

## Architecture

The server consists of:
- **SwiftDocParser**: Parses Swift documentation from various sources
- **SwiftAPIIndex**: Indexes and searches Swift Standard Library APIs
- **SwiftDocCache**: Manages local caching of documentation
- **SwiftLangStdioServer**: Main MCP server implementation

## Troubleshooting

### Server Not Starting

1. Verify Swift is installed: `swift --version`
2. Build the executable: `cd SwiftLangMCP && swift build`
3. Check MCP logs in Cursor AI

### Documentation Not Loading

1. Check cache directory permissions
2. Verify documentation sources are accessible
3. Clear cache if needed: `rm -rf ~/.swift-lang-mcp/cache`

