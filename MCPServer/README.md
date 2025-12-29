# SublerPlus MCP Server

## Quick Start

The MCP (Model Context Protocol) Server for SublerPlus provides a standardized API for AI assistants and external tools to interact with SublerPlus functionality.

### Enable the Server

Set an authentication token via environment variable or Keychain:

```bash
# Via environment variable
export MCP_TOKEN="your-secure-token-here"
export MCP_ENABLED="true"

# Or via Keychain (in application Settings)
# Store token with key: "mcp_token"
```

The server will automatically start on port 8081 when the application launches.

### Test the Server

```bash
# Health check
curl http://127.0.0.1:8081/mcp/v1/health

# List resources (with auth)
curl -H "Authorization: Bearer your-token" \
  http://127.0.0.1:8081/mcp/v1/resources/list

# Search metadata
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token" \
  -d '{"name": "search_metadata", "arguments": {"query": "The Matrix"}}' \
  http://127.0.0.1:8081/mcp/v1/tools/call
```

## Architecture

- **MCPServer.swift**: Main server implementation with MCP protocol handlers
- **MCPIntegration.swift**: Integration helper for application setup

## Documentation

See `docs/MCP_SERVER.md` for complete documentation including:
- All available resources and tools
- API reference
- Security considerations
- Usage examples

See `docs/MCP_IMPLEMENTATION_PLAN.md` for:
- Detailed architecture
- Integration points
- Maintenance guidelines
- Future enhancements

