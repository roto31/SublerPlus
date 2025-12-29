# Apple Open Source MCP Server

## Overview

The Apple Open Source MCP Server provides access to Apple's open source repositories on GitHub, including documentation, code examples, and repository information through the Model Context Protocol.

## Features

- **Repository Discovery**: Search and browse all Apple Open Source repositories
- **Documentation Access**: Retrieve README files and documentation from repositories
- **Code Examples**: Extract and search code examples from repositories
- **Full-Text Search**: Search across repository names, descriptions, topics, and documentation
- **Caching**: Local caching of repository data and documentation for fast access
- **Rate Limit Handling**: Respects GitHub API rate limits with proper error handling

## Installation

The Apple Open Source MCP server is included in the SublerPlus workspace. Build it with:

```bash
cd AppleOpenSourceMCP
swift build --product AppleOpenSourceMCPExecutable
```

## Configuration

### Basic Configuration

Add to your `mcp.json`:

```json
{
  "mcpServers": {
    "Apple Open Source": {
      "type": "stdio",
      "command": "swift",
      "args": [
        "run",
        "--package-path",
        "${workspaceFolder}/AppleOpenSourceMCP",
        "AppleOpenSourceMCPExecutable"
      ]
    }
  }
}
```

### With GitHub Token (Recommended)

For higher rate limits (5000/hour vs 60/hour), configure a GitHub token:

```json
{
  "mcpServers": {
    "Apple Open Source": {
      "type": "stdio",
      "command": "swift",
      "args": [
        "run",
        "--package-path",
        "${workspaceFolder}/AppleOpenSourceMCP",
        "AppleOpenSourceMCPExecutable"
      ],
      "env": {
        "GITHUB_TOKEN": "${env:GITHUB_TOKEN}"
      }
    }
  }
}
```

**Setting up GitHub Token:**

1. Create a GitHub Personal Access Token:
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Generate a token with `public_repo` scope (read-only is sufficient)

2. Set environment variable:
   ```bash
   export GITHUB_TOKEN="your-token-here"
   ```

3. Or use `.env` file in project root:
   ```
   GITHUB_TOKEN=your-token-here
   ```

## Available Resources

- `apple-opensource://repositories` - List of all Apple Open Source repositories
- `apple-opensource://repository/{name}` - Detailed information about a specific repository
- `apple-opensource://documentation/{name}` - Documentation and README for a repository

## Available Tools

### search_repositories

Search Apple Open Source repositories by name, description, topics, or language.

**Parameters:**
- `query` (required): Search query string

**Example:**
```
@Apple Open Source search_repositories query="swift"
```

### get_repository_info

Get detailed information about a specific repository.

**Parameters:**
- `repository` (required): Repository name

**Example:**
```
@Apple Open Source get_repository_info repository="swift"
```

### get_documentation

Get documentation and README for a repository.

**Parameters:**
- `repository` (required): Repository name

**Example:**
```
@Apple Open Source get_documentation repository="swift"
```

### search_documentation

Search across all repository documentation.

**Parameters:**
- `query` (required): Search query
- `repository` (optional): Limit search to specific repository

**Example:**
```
@Apple Open Source search_documentation query="async await" repository="swift"
```

### get_code_examples

Get code examples from a repository.

**Parameters:**
- `repository` (required): Repository name
- `language` (optional): Filter by programming language

**Example:**
```
@Apple Open Source get_code_examples repository="swift" language="swift"
```

## Cache Location

Data is cached in:
- `~/.apple-open-source-mcp/repositories/` - Repository cache (24 hour expiration)
- `~/.apple-open-source-mcp/index/` - Search index
- `~/.apple-open-source-mcp/documentation/` - Parsed documentation cache (7 day expiration)

## Architecture

The server consists of:
- **AppleOpenSourceStdioServer**: Main MCP protocol handler (JSON-RPC 2.0)
- **GitHubAPIClient**: GitHub API integration with rate limiting (actor)
- **RepositoryManager**: Repository discovery and caching (actor)
- **DocumentationParser**: Documentation extraction and parsing (actor)
- **RepositoryIndexer**: Searchable index management (actor)
- **CodeExampleExtractor**: Code example identification (actor)

## Troubleshooting

### Server Not Starting

1. Verify Swift is installed:
   ```bash
   swift --version
   ```

2. Build the executable:
   ```bash
   cd AppleOpenSourceMCP
   swift build --product AppleOpenSourceMCPExecutable
   ```

3. Check MCP logs in Cursor AI:
   - Open Output panel: `Cmd+Shift+U` (macOS) or `Ctrl+Shift+U` (Windows/Linux)
   - Select "MCP Logs" from dropdown
   - Look for initialization errors or connection issues

### GitHub API Rate Limit Issues

**Symptoms:**
- Error messages about rate limit exceeded
- Slow or failed repository fetching

**Solutions:**
1. Configure GitHub token for higher rate limits (5000/hour vs 60/hour)
2. Wait for rate limit reset (check error message for reset time)
3. Clear cache to use cached data: `rm -rf ~/.apple-open-source-mcp/repositories/`

**Check Rate Limit Status:**
The server logs rate limit information. Check MCP logs in Cursor AI for current rate limit status.

### Documentation Not Loading

1. Check cache directory permissions:
   ```bash
   ls -la ~/.apple-open-source-mcp/
   ```

2. Verify repository exists:
   ```bash
   # Test with get_repository_info tool first
   ```

3. Clear documentation cache if needed:
   ```bash
   rm -rf ~/.apple-open-source-mcp/documentation/
   ```

### Network Connectivity Issues

**Offline Mode:**
The server can work with cached data when offline:
- Repository list (if cached within 24 hours)
- Previously fetched documentation
- Search index

**Error Messages:**
- Check internet connection
- Verify GitHub API is accessible
- Review MCP logs for detailed error information

## Security Best Practices

1. **Token Management**:
   - Never commit GitHub tokens to version control
   - Use environment variables only
   - Rotate tokens periodically
   - Use tokens with minimal required permissions

2. **Configuration Security**:
   - Keep `mcp.json` out of version control if it contains tokens
   - Use `${env:VARIABLE}` interpolation for sensitive data
   - Review server code before installation

3. **Cache Security**:
   - Cache directory is in user home directory
   - No sensitive data is cached (only public repository information)
   - Cache can be cleared safely

## Performance Optimization

### Cache Management

- Repository list: Cached for 24 hours
- Documentation: Cached for 7 days
- Index: Persisted to disk for fast startup

### Background Operations

- Repository refresh happens in background
- Indexing happens asynchronously
- Documentation parsing is lazy-loaded

### Rate Limit Optimization

- Aggressive caching minimizes API calls
- Conditional requests when possible
- Batch operations where supported

## Usage Examples

### Search for Swift-related Repositories

```
@Apple Open Source search_repositories query="swift"
```

### Get Swift Repository Information

```
@Apple Open Source get_repository_info repository="swift"
```

### Get Swift Documentation

```
@Apple Open Source get_documentation repository="swift"
```

### Search Documentation for Async/Await

```
@Apple Open Source search_documentation query="async await"
```

### Get Code Examples from Swift Repository

```
@Apple Open Source get_code_examples repository="swift" language="swift"
```

## Protocol Compliance

- **Protocol Version**: 2024-11-05 (Cursor AI specification)
- **Transport**: stdio (local command-line server)
- **Error Codes**: Full JSON-RPC 2.0 error code support
- **Request Correlation**: All responses include request `id`

## Support

For issues or questions:

1. Check MCP logs in Cursor AI (`Cmd+Shift+U` → "MCP Logs")
2. Review cache directory: `~/.apple-open-source-mcp/`
3. Verify GitHub API access
4. Check rate limit status in logs
5. Review documentation in `docs/` directory

