# ModelScope Swift MCP Server

## Overview

The ModelScope Swift MCP Server provides access to ModelScope Swift library API documentation, model information, and usage examples through the Model Context Protocol.

## Features

- **API Documentation**: Search and access ModelScope Swift API documentation
- **Model Catalog**: Search and retrieve information about available models
- **Usage Examples**: Access code examples and tutorials
- **Caching**: Local caching of parsed documentation for fast access

## Installation

The ModelScope Swift MCP server is included in the SublerPlus workspace. Build it with:

```bash
cd ModelScopeSwiftMCP
swift build --product ModelScopeMCPExecutable
```

## Configuration

Add to your `mcp.json`:

```json
{
  "mcpServers": {
    "ModelScope Swift": {
      "command": "swift",
      "args": [
        "run",
        "--package-path",
        "${workspaceFolder}/ModelScopeSwiftMCP",
        "ModelScopeMCPExecutable"
      ]
    }
  }
}
```

## Available Resources

- `modelscope://api` - ModelScope Swift API documentation
- `modelscope://models` - Available models catalog
- `modelscope://examples` - Usage examples

## Available Tools

### search_modelscope_api

Search ModelScope Swift API documentation.

**Parameters:**
- `query` (required): Search query string

**Example:**
```
@ModelScope Swift search_modelscope_api query="inference"
```

### get_model_info

Get information about a ModelScope model.

**Parameters:**
- `modelId` (required): Model ID

**Example:**
```
@ModelScope Swift get_model_info modelId="model-id-here"
```

### search_models

Search available models.

**Parameters:**
- `query` (required): Search query

**Example:**
```
@ModelScope Swift search_models query="text generation"
```

### get_usage_example

Get usage examples.

**Parameters:**
- `topic` (required): Topic or keyword

**Example:**
```
@ModelScope Swift get_usage_example topic="model loading"
```

## Cache Location

Documentation cache is stored in:
- `~/.modelscope-swift-mcp/cache/` - Cached documentation sections
- `~/.modelscope-swift-mcp/api-index/` - API index cache

## Architecture

The server consists of:
- **ModelScopeDocParser**: Parses ModelScope Swift documentation
- **ModelScopeAPIIndex**: Indexes and searches ModelScope APIs and models
- **ModelScopeDocCache**: Manages local caching of documentation
- **ModelScopeStdioServer**: Main MCP server implementation

## Troubleshooting

### Server Not Starting

1. Verify Swift is installed: `swift --version`
2. Build the executable: `cd ModelScopeSwiftMCP && swift build`
3. Check MCP logs in Cursor AI

### Documentation Not Loading

1. Check cache directory permissions
2. Verify ModelScope repository is accessible
3. Clear cache if needed: `rm -rf ~/.modelscope-swift-mcp/cache`

