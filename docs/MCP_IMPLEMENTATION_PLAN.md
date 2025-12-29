# MCP Server Implementation Plan for SublerPlus

## Executive Summary

This document provides a comprehensive technical plan for implementing an MCP (Model Context Protocol) Server for SublerPlus. The MCP server will expose SublerPlus functionality as resources and tools, enabling AI assistants and external applications to interact with the application programmatically.

## 1. Architecture Overview

### 1.1 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SublerPlus Application                    │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Metadata   │  │    Job       │  │    Status    │      │
│  │  Pipeline   │  │    Queue     │  │    Stream    │      │
│  └──────┬──────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                │                  │               │
│         └────────────────┼──────────────────┘               │
│                          │                                   │
│                   ┌──────▼───────┐                          │
│                   │  MCP Server  │                          │
│                   └──────┬───────┘                          │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           │ HTTP/REST API
                           │ (Port 8081)
                           │
┌──────────────────────────▼──────────────────────────────────┐
│              AI Assistants / External Tools                  │
│  - Cursor AI                                                │
│  - Custom Scripts                                           │
│  - Automation Tools                                          │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Component Structure

#### Core Components

1. **MCPServer** (`MCPServer/MCPServer.swift`)
   - Main server implementation
   - Handles HTTP requests and routing
   - Implements MCP protocol endpoints
   - Manages authentication and authorization

2. **MCPIntegration** (`MCPServer/MCPIntegration.swift`)
   - Integration helper for application initialization
   - Provides factory methods for server setup
   - Handles dependency injection

3. **Resources** (implemented in MCPServer)
   - Status events resource
   - Job queue resource
   - Metadata providers resource
   - Settings resource

4. **Tools** (implemented in MCPServer)
   - Search metadata tool
   - Enrich file tool
   - Job management tools
   - Status query tools

### 1.3 Protocol Compliance

The implementation follows the MCP protocol specification (version 2024-11-05):

- **Initialization**: Protocol version negotiation and capability discovery
- **Resources**: Read-only data endpoints with URI-based addressing
- **Tools**: Action endpoints with JSON schema validation
- **Error Handling**: Standardized error responses
- **Authentication**: Bearer token support

## 2. Integration Points

### 2.1 Application Integration

The MCP server integrates with existing SublerPlus components:

#### MetadataPipeline
- **Purpose**: Core metadata enrichment engine
- **Integration**: Used by `enrich_file` tool
- **Methods Used**: `enrich(file:includeAdult:preference:)`

#### ProvidersRegistry
- **Purpose**: Manages metadata provider instances
- **Integration**: Used for provider listing and search operations
- **Methods Used**: `all(includeAdult:)`

#### StatusStream
- **Purpose**: Application-wide status event stream
- **Integration**: Provides status events resource
- **Methods Used**: `recent(limit:)`, `add(_:)`

#### JobQueue
- **Purpose**: Manages file processing queue
- **Integration**: Provides job queue resource and job management tools
- **Methods Used**: `snapshot()`, `getStatistics()`, `enqueue(_:with:)`

### 2.2 Initialization Flow

```swift
// In App/Main.swift - AppDependencies.build()
1. Initialize core components (pipeline, registry, statusStream, jobQueue)
2. Check for MCP_ENABLED or MCP_TOKEN
3. If enabled, create MCPServer instance
4. Start server on port 8081 (configurable)
5. Log startup status
```

### 2.3 Configuration

#### Environment Variables
- `MCP_ENABLED`: Enable/disable MCP server (default: auto-detect from token)
- `MCP_TOKEN`: Authentication token
- `MCP_PORT`: Server port (default: 8081)

#### Keychain Storage
- Key: `mcp_token` - Stores authentication token securely

## 3. Resource Implementation

### 3.1 Status Events Resource

**URI**: `sublerplus://status`

**Purpose**: Provides recent status events from the application

**Implementation**:
```swift
private func readStatusResource() async throws -> HttpResponse {
    let events = await statusStream.recent(limit: 100)
    // Return structured response with events array
}
```

**Response Format**:
```json
{
  "events": [StatusEvent],
  "count": 50,
  "latest": StatusEvent
}
```

### 3.2 Job Queue Resource

**URI**: `sublerplus://jobs`

**Purpose**: Provides current job queue status and statistics

**Implementation**:
```swift
private func readJobsResource() async throws -> HttpResponse {
    let stats = await jobQueue.getStatistics()
    let jobs = await jobQueue.snapshot()
    // Return jobs and statistics
}
```

**Response Format**:
```json
{
  "jobs": [JobInfo],
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

### 3.3 Metadata Providers Resource

**URI**: `sublerplus://providers`

**Purpose**: Lists available metadata providers and their configuration

**Implementation**:
```swift
private func readProvidersResource() async throws -> HttpResponse {
    let providers = registry.all(includeAdult: true)
    // Map to provider info structure
}
```

### 3.4 Settings Resource

**URI**: `sublerplus://settings`

**Purpose**: Provides current application settings

**Status**: Placeholder - requires SettingsStore integration

## 4. Tool Implementation

### 4.1 Search Metadata Tool

**Name**: `search_metadata`

**Purpose**: Search for metadata across all configured providers

**Parameters**:
- `query` (string, required): Search query
- `includeAdult` (boolean, optional): Include adult providers
- `year` (integer, optional): Filter by year

**Implementation Flow**:
1. Validate parameters
2. Create MetadataHint from parameters
3. Query all providers in parallel
4. Aggregate results
5. Return formatted response

### 4.2 Enrich File Tool

**Name**: `enrich_file`

**Purpose**: Enrich a media file with metadata

**Parameters**:
- `filePath` (string, required): File path
- `includeAdult` (boolean, optional): Include adult providers
- `preference` (string, optional): Provider preference strategy

**Implementation Flow**:
1. Validate file path and format
2. Call pipeline.enrich()
3. Handle deferred disambiguation
4. Return metadata details or deferral status

### 4.3 Job Management Tools

**Tools**:
- `get_job_status`: Get status of specific job
- `queue_file`: Add file to processing queue
- `get_status_events`: Get recent status events

## 5. Security Architecture

### 5.1 Authentication

**Methods**:
1. Bearer token in Authorization header
2. X-Auth-Token header (alternative)
3. Token from environment variable or Keychain

**Implementation**:
```swift
private func authorized(_ req: HttpRequest) -> Bool {
    if let token = authToken, !token.isEmpty {
        return req.headers["authorization"] == "Bearer \(token)" ||
               req.headers["x-auth-token"] == token
    }
    return true // No auth if no token configured
}
```

### 5.2 Network Security

- **Binding**: Server binds to 127.0.0.1 only (localhost)
- **CORS**: Configured for cross-origin requests (can be restricted)
- **Content Validation**: JSON content-type and size limits

### 5.3 Best Practices

1. Always use authentication in production
2. Store tokens in Keychain, not plaintext
3. Use strong, randomly generated tokens
4. Rotate tokens periodically
5. Monitor access logs

## 6. Error Handling

### 6.1 Error Response Format

```json
{
  "error": "Error message",
  "status": 400
}
```

### 6.2 Error Categories

- **400 Bad Request**: Invalid parameters or request format
- **401 Unauthorized**: Authentication failure
- **404 Not Found**: Resource or job not found
- **415 Unsupported Media Type**: Invalid file format
- **500 Internal Server Error**: Processing failure

### 6.3 Error Logging

All errors are logged to StatusStream for application visibility.

## 7. Testing Strategy

### 7.1 Unit Tests

- Resource handlers
- Tool handlers
- Authentication logic
- Error handling

### 7.2 Integration Tests

- End-to-end tool execution
- Resource retrieval
- Authentication flows
- Error scenarios

### 7.3 Manual Testing

- curl commands for all endpoints
- Python client examples
- Authentication verification
- Performance testing

## 8. Maintenance and Updates

### 8.1 Version Management

- MCP server version aligns with SublerPlus version
- Protocol version specified in initialize endpoint
- Backward compatibility considerations

### 8.2 Adding New Resources

1. Add resource definition to `setupResources()`
2. Implement handler in `handleResourceRead()`
3. Update documentation
4. Add tests

### 8.3 Adding New Tools

1. Add tool definition to `setupTools()`
2. Implement handler in `handleToolCall()`
3. Update documentation
4. Add tests

### 8.4 Protocol Updates

When MCP protocol specification updates:
1. Review changes
2. Update protocol version
3. Implement new capabilities
4. Maintain backward compatibility
5. Update documentation

## 9. Performance Considerations

### 9.1 Concurrency

- Async/await for all I/O operations
- Parallel provider queries
- Non-blocking request handling

### 9.2 Caching

- Status events limited to recent items
- Job queue snapshot cached
- Provider list cached

### 9.3 Rate Limiting

- Consider adding rate limiting for production
- Token bucket algorithm (similar to WebServer)
- Configurable limits per endpoint

## 10. Deployment

### 10.1 Build Integration

The MCP server is included in SublerPlusCore target:
- Files in `MCPServer/` directory
- Automatically compiled with application
- No separate build step required

### 10.2 Runtime Activation

- Automatic startup if token configured
- Environment variable control
- Graceful failure if port unavailable

### 10.3 Monitoring

- Status events logged to application log
- Health check endpoint available
- Error tracking via StatusStream

## 11. Future Enhancements

### 11.1 Planned Features

- WebSocket support for real-time updates
- Resource subscriptions
- Batch operations
- Advanced filtering
- Metrics endpoints
- Plugin system

### 11.2 Integration Opportunities

- Cursor AI deep integration
- VS Code extension
- Command-line tools
- Automation frameworks
- CI/CD pipelines

## 12. Conclusion

The MCP server implementation provides a robust, secure, and extensible interface for AI assistants and external tools to interact with SublerPlus. The modular architecture ensures easy maintenance and future enhancements while maintaining compatibility with the MCP protocol specification.

The implementation follows best practices for security, error handling, and performance, making it suitable for both development and production environments.

