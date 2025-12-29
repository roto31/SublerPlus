# MCP Log Parsing Documentation

## Overview

The MCP server includes comprehensive log parsing capabilities for analyzing SublerPlus application logs, MCP access logs, and Cursor AI development patterns.

## Log Sources

### 1. Application Logs

**Location**: `logs/sublerplus.log` (project root)

**Format**:
```
[ISO8601-Timestamp] [LEVEL] [CATEGORY] Message
```

**Example**:
```
[2024-01-01T12:00:00Z] [INFO] [providers] TPDB search completed: 5 results
[2024-01-01T12:00:01Z] [ERROR] [network] Failed to connect to API
```

**Categories**:
- `general` - General application events
- `network` - Network operations
- `providers` - Metadata provider operations
- `pipeline` - Metadata pipeline operations
- `webui` - WebUI server events
- `storage` - Storage/Keychain operations

**Levels**:
- `INFO` - Informational messages
- `ERROR` - Error messages
- `DEBUG` - Debug messages (only when LOG_LEVEL=normal)

### 2. MCP Access Logs

**Location**: `~/.cursor/sublerplus-mcp-logs/access.log`

**Format**: JSON lines (one JSON object per line)

**Example**:
```json
{"timestamp":"2024-01-01T12:00:00Z","operation":"tools/call","tool":"search_metadata","success":true,"duration":0.5}
{"timestamp":"2024-01-01T12:00:01Z","operation":"resources/read","resource":"sublerplus://status","success":true,"duration":0.1}
```

**Fields**:
- `timestamp` - ISO8601 timestamp
- `operation` - Operation type (tools/call, resources/read, etc.)
- `tool` - Tool name (if operation is tools/call)
- `resource` - Resource URI (if operation is resources/read)
- `success` - Boolean indicating success
- `duration` - Operation duration in seconds
- `error` - Error message (if success is false)

### 3. Cursor AI Development Patterns

**Location**: `~/.cursor/sublerplus-mcp-logs/` (various files)

Tracks development patterns and code generation usage through MCP tool calls.

## Log Parsing Methods

### Using MCP Tools

#### Analyze Logs

```json
{
  "name": "analyze_logs",
  "arguments": {
    "timeRange": "2024-01-01T00:00:00Z/2024-01-02T00:00:00Z",
    "category": "providers",
    "level": "ERROR"
  }
}
```

**Response**:
```json
{
  "totalEntries": 150,
  "entriesByLevel": {
    "INFO": 120,
    "ERROR": 30
  },
  "entriesByCategory": {
    "providers": 50,
    "network": 30,
    "pipeline": 70
  },
  "entriesBySource": {
    "application": 140,
    "mcp": 10
  },
  "timeRange": {
    "start": "2024-01-01T00:00:00Z",
    "end": "2024-01-02T00:00:00Z"
  },
  "averageEntriesPerDay": 150.0
}
```

#### Search Logs

```json
{
  "name": "search_logs",
  "arguments": {
    "pattern": "failed",
    "limit": 50
  }
}
```

**Response**: Array of matching log entries

#### Get Log Statistics

```json
{
  "name": "get_log_statistics",
  "arguments": {}
}
```

**Response**: Overall log statistics

#### Export Logs

```json
{
  "name": "export_logs",
  "arguments": {
    "format": "csv",
    "timeRange": "2024-01-01T00:00:00Z/2024-01-02T00:00:00Z"
  }
}
```

**Response**: Logs in specified format (json or csv)

### Using MCP Resources

#### Read Application Logs

```
sublerplus://logs/application
```

Returns all application logs as JSON array.

#### Read MCP Access Logs

```
sublerplus://logs/mcp
```

Returns all MCP access logs as JSON array.

#### Read Log Analysis

```
sublerplus://logs/analysis
```

Returns parsed log analysis and statistics.

### Using Shell Scripts

#### Parse SublerPlus Logs

```bash
./scripts/parse-sublerplus-logs.sh \
  --time-range "2024-01-01T00:00:00Z/2024-01-02T00:00:00Z" \
  --category "providers" \
  --level "ERROR" \
  --output json \
  --limit 100
```

**Options**:
- `--time-range` - Filter by time range (ISO8601 interval)
- `--category` - Filter by category
- `--level` - Filter by level (INFO, ERROR, DEBUG)
- `--output` - Output format (json, csv)
- `--limit` - Limit number of results
- `--log-dir` - Log directory (default: logs)
- `--output-file` - Output file (default: stdout)

#### Parse MCP Logs

```bash
./scripts/parse-mcp-logs.sh \
  --operation "tools/call" \
  --time-range "2024-01-01/2024-01-02" \
  --output json \
  --limit 50
```

**Options**:
- `--time-range` - Filter by time range
- `--operation` - Filter by operation type
- `--output` - Output format (json, csv)
- `--limit` - Limit number of results
- `--output-file` - Output file (default: stdout)

#### Analyze Cursor Logs

```bash
./scripts/analyze-cursor-logs.sh \
  --time-range "2024-01-01/2024-01-02" \
  --output json
```

**Options**:
- `--time-range` - Filter by time range
- `--output` - Output format (json, csv)
- `--output-file` - Output file (default: stdout)

## Log Indexing

The MCP server maintains indexes for fast log querying:

### Time-Based Index

**Location**: `~/.cursor/sublerplus-mcp-logs/indexes/time-index.json`

Maps dates to line numbers for fast time-range queries.

### Operation-Based Index

**Location**: `~/.cursor/sublerplus-mcp-logs/indexes/operation-index.json`

Maps operation types to line numbers for fast operation filtering.

### Index Updates

Indexes are automatically updated:
- After each log write (incremental)
- Weekly (full rebuild)
- On demand via maintenance system

## Log Maintenance

### Automatic Maintenance

The MCP server automatically:

1. **Rotates Logs**: Daily or when size exceeds 10MB
2. **Archives Logs**: Moves logs older than 30 days to archive
3. **Compresses Archives**: Gzip compression for archived logs
4. **Cleans Cache**: Removes parsed log cache older than 7 days
5. **Updates Indexes**: Maintains time and operation indexes

### Manual Maintenance

Run maintenance manually:

```swift
let maintenance = MCPLogMaintenance()
try await maintenance.runMaintenance()
```

Or use the cleanup script:

```bash
# Clean old logs (older than 30 days)
# Rebuild indexes
# Clean cache
```

## Log Query Performance

### Optimization Tips

1. **Use Time Ranges**: Always specify time ranges for faster queries
2. **Use Indexes**: Query by indexed fields (date, operation) for best performance
3. **Limit Results**: Use `--limit` to reduce result set size
4. **Cache Results**: Parsed logs are cached for 7 days

### Performance Metrics

- **Index Query**: < 10ms for time-range queries
- **Full Scan**: ~100ms per 10,000 log entries
- **Cache Hit**: < 1ms for cached results

## Log Security

### Secret Scrubbing

All log messages are automatically scrubbed to remove:
- API keys (`api_key=...`)
- Bearer tokens (`Bearer ...`)
- X-API-Key headers

### Access Control

- Log files are stored in user's home directory
- MCP server requires authentication token
- Log resources require proper authorization

### Encryption

Sensitive log entries can be encrypted (future enhancement).

## Troubleshooting

### Logs Not Parsing

1. Check log file format matches expected structure
2. Verify file permissions
3. Check for encoding issues (should be UTF-8)

### Index Errors

1. Rebuild indexes: `maintenance.updateIndexes()`
2. Check index file integrity
3. Verify JSON format

### Performance Issues

1. Check cache size (should be < 100MB)
2. Rebuild indexes if queries are slow
3. Use time ranges to limit query scope

## Examples

### Find All Errors in Last 24 Hours

```bash
./scripts/parse-sublerplus-logs.sh \
  --time-range "$(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ)/$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --level "ERROR" \
  --output json
```

### Export MCP Tool Usage Statistics

```bash
./scripts/parse-mcp-logs.sh \
  --operation "tools/call" \
  --output csv \
  --output-file mcp-usage.csv
```

### Analyze Provider Errors

```bash
./scripts/parse-sublerplus-logs.sh \
  --category "providers" \
  --level "ERROR" \
  --output json | jq '.[] | select(.message | contains("TPDB"))'
```

## Best Practices

1. **Regular Maintenance**: Run log maintenance weekly
2. **Archive Old Logs**: Keep archives for at least 90 days
3. **Monitor Log Size**: Alert if logs exceed 100MB
4. **Use Indexes**: Always query by indexed fields when possible
5. **Limit Results**: Use limits to prevent large result sets

## API Reference

See [MCP_SERVER.md](MCP_SERVER.md) for complete API documentation.

