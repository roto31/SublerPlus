# SublerPlus MCP Server

## Overview

The SublerPlus MCP (Model Context Protocol) Server provides a standardized interface for AI assistants and external tools to interact with SublerPlus. It exposes resources (status, jobs, providers) and tools (search, enrich, queue) through a RESTful API following the MCP protocol specification.

## Architecture

### Components

1. **MCPServer**: Main server implementation handling MCP protocol endpoints
2. **MCPIntegration**: Integration helper for initializing the server with application dependencies
3. **Resources**: Read-only data endpoints (status events, job queue, providers, settings)
4. **Tools**: Action endpoints (search metadata, enrich files, manage jobs)

### Protocol Endpoints

- `/mcp/v1/initialize` - Protocol initialization and capability negotiation
- `/mcp/v1/health` - Health check endpoint
- `/mcp/v1/resources/list` - List available resources
- `/mcp/v1/resources/read` - Read a specific resource
- `/mcp/v1/tools/list` - List available tools
- `/mcp/v1/tools/call` - Execute a tool

## Resources

### Status Events (`sublerplus://status`)

Returns recent status events from the application:

```json
{
  "events": [
    {
      "id": "uuid",
      "timestamp": "2024-01-01T00:00:00Z",
      "message": "Status message"
    }
  ],
  "count": 50,
  "latest": { ... }
}
```

### Job Queue (`sublerplus://jobs`)

Returns current job queue status and statistics:

```json
{
  "jobs": [
    {
      "id": "uuid",
      "url": "/path/to/file.mp4",
      "status": "queued|running|succeeded|failed",
      "message": "Status message"
    }
  ],
  "statistics": {
    "totalProcessed": 100,
    "successCount": 95,
    "failureCount": 5,
    "averageTime": 12.5,
    "queueLength": 10,
    "runningCount": 2
  }
}
```

### Metadata Providers (`sublerplus://providers`)

Returns list of configured metadata providers:

```json
{
  "providers": [
    {
      "id": "tmdb",
      "name": "TMDB",
      "isAdult": false,
      "isConfigured": true
    }
  ],
  "count": 3
}
```

### Settings (`sublerplus://settings`)

Returns current application settings (requires SettingsStore integration).

## Tools

### search_metadata

Search for metadata across all configured providers.

**Parameters:**
- `query` (string, required): Search query (title, show name, etc.)
- `includeAdult` (boolean, optional): Include adult content providers (default: false)
- `year` (integer, optional): Optional year to narrow search results

**Response:**
```json
{
  "results": [
    {
      "id": "uuid",
      "title": "Movie Title",
      "score": 8.5,
      "year": 2023,
      "source": "tmdb",
      "coverURL": "https://..."
    }
  ],
  "count": 10
}
```

### enrich_file

Enrich a media file with metadata from providers.

**Parameters:**
- `filePath` (string, required): Path to the media file to enrich
- `includeAdult` (boolean, optional): Include adult content providers (default: false)
- `preference` (string, optional): Provider preference strategy - "balanced", "scoreFirst", or "yearFirst" (default: "balanced")

**Response:**
```json
{
  "id": "uuid",
  "title": "Movie Title",
  "synopsis": "...",
  "releaseDate": "2023-01-01T00:00:00Z",
  ...
}
```

### get_job_status

Get status of a specific job by ID.

**Parameters:**
- `jobId` (string, required): UUID of the job

**Response:**
```json
{
  "id": "uuid",
  "url": "/path/to/file.mp4",
  "status": "running",
  "message": "Processing..."
}
```

### queue_file

Add a file to the processing queue.

**Parameters:**
- `filePath` (string, required): Path to the media file to queue

**Response:**
```json
{
  "message": "File queued successfully",
  "filePath": "/path/to/file.mp4"
}
```

### get_status_events

Get recent status events.

**Parameters:**
- `limit` (integer, optional): Maximum number of events to return (default: 50)

**Response:**
```json
{
  "events": [ ... ],
  "count": 50
}
```

## Configuration

### Environment Variables

- `MCP_ENABLED`: Set to "true" to enable the MCP server (default: enabled if MCP_TOKEN is set)
- `MCP_TOKEN`: Authentication token for MCP server access
- `MCP_PORT`: Port number for MCP server (default: 8081)

### Keychain Storage

The MCP server can also use Keychain-stored tokens:
- Key: `mcp_token` - Authentication token

### Authentication

The MCP server supports Bearer token authentication:
- Header: `Authorization: Bearer <token>` or `X-Auth-Token: <token>`
- If no token is configured, the server allows unauthenticated access (not recommended for production)

## Integration

### Starting the Server

The MCP server is automatically started when the application launches if:
1. `MCP_ENABLED` environment variable is set to "true", OR
2. `MCP_TOKEN` is set (either via environment or Keychain)

### Manual Initialization

```swift
let mcpServer = try MCPIntegration.startMCPServer(
    pipeline: pipeline,
    registry: registry,
    statusStream: statusStream,
    jobQueue: jobQueue,
    port: 8081,
    authToken: "your-token"
)
```

## Usage Examples

### Using curl

```bash
# List resources
curl -H "Authorization: Bearer your-token" \
  http://127.0.0.1:8081/mcp/v1/resources/list

# Read status resource
curl -H "Authorization: Bearer your-token" \
  "http://127.0.0.1:8081/mcp/v1/resources/read?uri=sublerplus://status"

# Search metadata
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token" \
  -d '{"name": "search_metadata", "arguments": {"query": "The Matrix", "year": 1999}}' \
  http://127.0.0.1:8081/mcp/v1/tools/call

# Enrich a file
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token" \
  -d '{"name": "enrich_file", "arguments": {"filePath": "/path/to/file.mp4"}}' \
  http://127.0.0.1:8081/mcp/v1/tools/call
```

### Using Python

```python
import requests

BASE_URL = "http://127.0.0.1:8081/mcp/v1"
TOKEN = "your-token"
HEADERS = {"Authorization": f"Bearer {TOKEN}"}

# List tools
response = requests.get(f"{BASE_URL}/tools/list", headers=HEADERS)
print(response.json())

# Search metadata
response = requests.post(
    f"{BASE_URL}/tools/call",
    headers={**HEADERS, "Content-Type": "application/json"},
    json={
        "name": "search_metadata",
        "arguments": {
            "query": "The Matrix",
            "year": 1999
        }
    }
)
print(response.json())
```

## Security Considerations

1. **Authentication**: Always use authentication tokens in production
2. **Network Binding**: Server binds to 127.0.0.1 only (localhost)
3. **CORS**: Configured to allow cross-origin requests (can be restricted if needed)
4. **Rate Limiting**: Consider adding rate limiting for production use
5. **Token Storage**: Prefer Keychain storage over environment variables

## Maintenance and Updates

### Version Alignment

The MCP server version should align with the SublerPlus application version. Update the version in:
- `MCPServer.swift` - ServerInfo.version
- This documentation

### Adding New Resources

1. Add resource definition to `setupResources()`
2. Implement handler in `handleResourceRead()`
3. Update this documentation

### Adding New Tools

1. Add tool definition to `setupTools()`
2. Implement handler in `handleToolCall()`
3. Update this documentation

### Protocol Updates

The MCP protocol version is specified in the initialize endpoint. When updating:
1. Update protocol version string
2. Review capability changes
3. Update client compatibility documentation

## Troubleshooting

### Server Not Starting

- Check that port 8081 is not in use
- Verify environment variables are set correctly
- Check application logs for error messages

### Authentication Failures

- Verify token is set correctly (environment or Keychain)
- Check Authorization header format
- Ensure token matches configured value

### Tool Execution Errors

- Verify file paths are absolute and accessible
- Check file format is supported (MP4, M4V, MOV)
- Review status events for detailed error messages

## Future Enhancements

- [ ] WebSocket support for real-time updates
- [ ] Resource subscriptions for push notifications
- [ ] Batch operations for multiple files
- [ ] Advanced filtering and querying
- [ ] Metrics and monitoring endpoints
- [ ] Plugin system for custom tools

