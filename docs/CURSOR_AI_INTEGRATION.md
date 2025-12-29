# Cursor AI Integration Guide

## Overview

This guide explains how to integrate the SublerPlus MCP Server with Cursor AI for AI-assisted development workflows.

## Prerequisites

- Cursor AI installed and configured
- SublerPlus project built and dependencies available
- Swift toolchain (Swift 5.9+)
- Node.js (v14+ recommended) - Required for Apple Dev MCP integration
- npm (comes with Node.js) - Required for Apple Dev MCP integration
- API keys configured (optional, for metadata providers)

## Installation

### Step 1: Copy Configuration File

Copy the MCP configuration template to your Cursor configuration:

```bash
# For project-specific configuration
mkdir -p .cursor
cp docs/mcp.json.template .cursor/mcp.json

# Or for global configuration
mkdir -p ~/.cursor
cp docs/mcp.json.template ~/.cursor/mcp.json
```

### Step 2: Configure Environment Variables

Set up environment variables for API keys and authentication:

```bash
# In your shell profile (~/.zshrc or ~/.bash_profile)
export MCP_TOKEN="your-secure-token-here"
export TPDB_API_KEY="your-tpdb-key"  # Optional
export TMDB_API_KEY="your-tmdb-key"  # Optional
export TVDB_API_KEY="your-tvdb-key"  # Optional
export OPENSUBTITLES_API_KEY="your-key"  # Optional
```

Or create a `.env` file in your project root:

```bash
MCP_TOKEN=your-secure-token-here
TPDB_API_KEY=your-tpdb-key
TMDB_API_KEY=your-tmdb-key
TVDB_API_KEY=your-tvdb-key
OPENSUBTITLES_API_KEY=your-key
```

### Step 3: Build the MCP Server

Build the MCP server executable:

```bash
swift build --product MCPServerExecutable
```

### Step 4: Install Apple Dev MCP (Optional)

To enable Apple Human Interface Guidelines and technical documentation search:

1. Install Node.js (if not already installed):
   ```bash
   brew install node
   ```

2. Install apple-dev-mcp globally:
   ```bash
   npm install -g apple-dev-mcp
   ```

3. Find the installation path:
   ```bash
   npm list -g apple-dev-mcp
   ```

4. Update your `mcp.json` to include the Apple Dev server (see configuration example below).

### Step 5: Restart Cursor AI

Restart Cursor AI to load the MCP server configuration.

## Verification

### Check MCP Server Status

1. Open Cursor AI
2. Open the Output panel (Cmd+Shift+U)
3. Select "MCP Logs" from the dropdown
4. Look for "SublerPlus MCP Server" in the logs

### Test MCP Tools

In Cursor AI chat, try:

```
@SublerPlus search_metadata query="The Matrix"
```

Or:

```
List all available SublerPlus resources
```

## Available Resources

The MCP server exposes the following resources:

- `sublerplus://status` - Recent status events
- `sublerplus://jobs` - Job queue status and statistics
- `sublerplus://providers` - Metadata provider configuration
- `sublerplus://settings` - Application settings
- `sublerplus://logs/application` - Application logs
- `sublerplus://logs/mcp` - MCP access logs
- `sublerplus://logs/analysis` - Log analysis and patterns

## Available Tools

### SublerPlus Tools

#### Metadata Tools

- `search_metadata` - Search for metadata across providers
- `enrich_file` - Enrich a media file with metadata
- `get_job_status` - Get status of a specific job
- `queue_file` - Add a file to processing queue
- `get_status_events` - Get recent status events

#### Log Analysis Tools

- `analyze_logs` - Analyze logs by time range, category, level
- `search_logs` - Search logs by pattern/keyword
- `get_log_statistics` - Get log statistics and metrics
- `export_logs` - Export logs in JSON or CSV format

### Apple Dev Tools (if Apple Dev MCP is configured)

- `search_human_interface_guidelines` - Search Apple Human Interface Guidelines with platform filters (iOS, macOS, watchOS, tvOS, visionOS)
- `search_technical_documentation` - Search Apple API documentation for frameworks (SwiftUI, UIKit, AppKit, etc.)
- `search_unified` - Combined design + technical documentation search that cross-references design principles with implementation details

### Swift Lang Tools (if Swift Lang MCP is configured)

- `search_swift_documentation` - Search Swift language documentation
- `get_api_reference` - Get API documentation for a Swift symbol
- `search_standard_library` - Search Swift Standard Library APIs
- `get_code_example` - Get code examples for a topic
- `search_evolution_proposals` - Search Swift Evolution proposals

### ModelScope Swift Tools (if ModelScope Swift MCP is configured)

- `search_modelscope_api` - Search ModelScope Swift API documentation
- `get_model_info` - Get information about a ModelScope model
- `search_models` - Search available models
- `get_usage_example` - Get usage examples

### Apple Open Source Tools (if Apple Open Source MCP is configured)

- `search_repositories` - Search Apple Open Source repositories by name, description, topics, or language
- `get_repository_info` - Get detailed information about a specific repository
- `get_documentation` - Get documentation and README for a repository
- `search_documentation` - Search across all repository documentation
- `get_code_examples` - Get code examples from a repository

### Subler Tools (if Subler MCP is configured)

- `search_code` - Search Subler codebase by query
- `find_class` - Find class definitions in Subler codebase
- `find_function` - Find function definitions in Subler codebase
- `get_file_contents` - Get file contents from Subler codebase
- `get_api_reference` - Get API reference for MP42Foundation class
- `analyze_mp4_file` - Analyze MP4 file using MP42Foundation (read-only)
- `get_track_info` - Get track information from MP4 file
- `get_metadata` - Extract metadata from MP4 file
- `list_supported_codecs` - List codecs supported by MP42Foundation
- `test_import` - Test file import capabilities (read-only)

## Usage Examples

### SublerPlus Tools

#### Search for Metadata

```
@SublerPlus search_metadata query="Inception" year=2010
```

#### Enrich a File

```
@SublerPlus enrich_file filePath="/path/to/movie.mp4"
```

#### Analyze Logs

```
@SublerPlus analyze_logs timeRange="2024-01-01T00:00:00Z/2024-01-02T00:00:00Z" category="providers"
```

#### Get Job Status

```
@SublerPlus get_job_status jobId="uuid-here"
```

### Apple Dev Tools (if configured)

#### Search Human Interface Guidelines

```
@Apple Dev search_human_interface_guidelines query="Tab Bars" platform="iOS"
```

#### Search Technical Documentation

```
@Apple Dev search_technical_documentation query="Button" framework="SwiftUI"
```

#### Unified Search

```
@Apple Dev search_unified query="navigation" platform="iOS"
```

### Swift Lang Tools (if configured)

#### Search Swift Documentation

```
@Swift Lang search_swift_documentation query="async await" category="language"
```

#### Get API Reference

```
@Swift Lang get_api_reference symbol="Array"
```

#### Search Standard Library

```
@Swift Lang search_standard_library query="String"
```

### ModelScope Swift Tools (if configured)

#### Search ModelScope API

```
@ModelScope Swift search_modelscope_api query="inference"
```

#### Get Model Info

```
@ModelScope Swift get_model_info modelId="model-id-here"
```

#### Search Models

```
@ModelScope Swift search_models query="text generation"
```

### Apple Open Source Tools (if configured)

#### Search Repositories

```
@Apple Open Source search_repositories query="swift"
```

#### Get Repository Info

```
@Apple Open Source get_repository_info repository="swift"
```

#### Get Documentation

```
@Apple Open Source get_documentation repository="swift"
```

#### Search Documentation

```
@Apple Open Source search_documentation query="async await"
```

#### Get Code Examples

```
@Apple Open Source get_code_examples repository="swift" language="swift"
```

### Subler Tools (if configured)

#### Search Code

```
@Subler search_code query="MP42File" language="Objective-C"
```

#### Find Class

```
@Subler find_class className="MP42File"
```

#### Get API Reference

```
@Subler get_api_reference className="MP42File"
```

#### Analyze MP4 File

```
@Subler analyze_mp4_file filePath="/path/to/video.mp4"
```

#### Get File Contents

```
@Subler get_file_contents filePath="MP42Foundation/MP42/MP42File.h"
```

## Troubleshooting

### MCP Server Not Starting

1. Check that Swift is in your PATH:
   ```bash
   which swift
   ```

2. Verify the executable exists:
   ```bash
   swift build --product MCPServerExecutable
   ls -la .build/debug/MCPServerExecutable
   ```

3. Check MCP logs in Cursor AI for error messages

### Apple Dev MCP Issues

1. Verify Node.js is installed:
   ```bash
   node --version
   npm --version
   ```

2. Check apple-dev-mcp installation:
   ```bash
   npm list -g apple-dev-mcp
   ```

3. Verify the server.js path in `mcp.json` matches your installation:
   - Homebrew (Intel): `/usr/local/lib/node_modules/apple-dev-mcp/dist/server.js`
   - Homebrew (Apple Silicon): `/opt/homebrew/lib/node_modules/apple-dev-mcp/dist/server.js`
   - nvm: `~/.nvm/versions/node/[version]/lib/node_modules/apple-dev-mcp/dist/server.js`

4. If path differs, update the `args` array in `mcp.json` with the correct path

### Swift Lang MCP Issues

1. Verify Swift toolchain is available:
   ```bash
   swift --version
   ```

2. Build the Swift Lang MCP executable:
   ```bash
   cd SwiftLangMCP
   swift build --product SwiftLangMCPExecutable
   ```

3. Verify the package path in `mcp.json` is correct relative to workspace root

### ModelScope Swift MCP Issues

1. Verify Swift toolchain is available:
   ```bash
   swift --version
   ```

2. Build the ModelScope Swift MCP executable:
   ```bash
   cd ModelScopeSwiftMCP
   swift build --product ModelScopeMCPExecutable
   ```

3. Verify the package path in `mcp.json` is correct relative to workspace root

### Authentication Errors

- Verify `MCP_TOKEN` is set in environment or `.env` file
- Check that the token matches what's expected

### Tool Execution Failures

- Check that required parameters are provided
- Verify file paths are absolute and accessible
- Review status events for detailed error messages

### Log Parsing Issues

- Ensure log files exist in `logs/` directory
- Check file permissions
- Verify log format matches expected structure

## Configuration Options

### Project-Specific vs Global

- **Project-specific** (`.cursor/mcp.json`): MCP server only available in this project
- **Global** (`~/.cursor/mcp.json`): MCP server available in all projects

### Environment Variable Interpolation

The configuration supports variable interpolation:

- `${env:VAR_NAME}` - Environment variable
- `${workspaceFolder}` - Project root directory
- `${userHome}` - User home directory

### Custom Command

You can customize the command in `mcp.json`:

```json
{
  "mcpServers": {
    "sublerplus": {
      "command": "/usr/local/bin/swift",
      "args": ["run", "--package-path", "${workspaceFolder}", "MCPServerExecutable"]
    },
    "Apple Dev": {
      "command": "node",
      "args": ["/opt/homebrew/lib/node_modules/apple-dev-mcp/dist/server.js"]
    }
  }
}
```

**Note**: Adjust the Apple Dev server path based on your Node.js installation location.

## Security Considerations

1. **Token Security**: Store `MCP_TOKEN` securely, never commit to version control
2. **API Keys**: Use environment variables or Keychain, not hardcoded values
3. **File Access**: MCP server only accesses files you explicitly specify
4. **Network**: Server binds to localhost only, no external network access

## Advanced Usage

### Custom Log Parsing

Use the log parsing scripts directly:

```bash
./scripts/parse-sublerplus-logs.sh --time-range "2024-01-01/2024-01-02" --output json
```

### Log Maintenance

The MCP server automatically maintains logs:
- Rotates logs daily or when size exceeds 10MB
- Archives logs older than 30 days
- Cleans cache files older than 7 days
- Maintains indexes for fast querying

### Integration with Cursor AI Workflows

The MCP server integrates seamlessly with Cursor AI's development workflows:

- **Code Generation**: Use metadata search to inform code generation
- **Debugging**: Analyze logs to identify issues
- **Testing**: Queue files for processing during development
- **Monitoring**: Track job status and application state

## Support

For issues or questions:

1. Check MCP logs in Cursor AI
2. Review application logs in `logs/sublerplus.log`
3. Check MCP access logs in `~/.cursor/sublerplus-mcp-logs/`
4. Review documentation in `docs/` directory

## Next Steps

- Read [MCP_LOG_PARSING.md](MCP_LOG_PARSING.md) for detailed log parsing documentation
- Review [MCP_SERVER.md](MCP_SERVER.md) for API reference
- See [MCP_IMPLEMENTATION_PLAN.md](MCP_IMPLEMENTATION_PLAN.md) for architecture details

