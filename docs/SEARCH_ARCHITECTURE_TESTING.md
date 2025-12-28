# Subler Search Architecture Testing Guide

## Overview

This document describes the comprehensive test suite for the Subler search architecture replication. The tests verify all critical functionality including single provider search, multi-provider coordination, incremental streaming, cancellation, and priority-based execution.

## Test File

**Location**: `Tests/SublerSearchArchitectureTests.swift`

## Test Coverage

### 1. Single Provider Tests

#### `testSingleProviderSearch()`
- **Purpose**: Verifies that a single provider can perform a movie search
- **What it tests**:
  - Provider returns correct results
  - Results are properly converted from modern `MetadataResult` to Subler's `MetadataResult`
  - Media kind is correctly set

#### `testSingleProviderTVSearch()`
- **Purpose**: Verifies TV show search functionality
- **What it tests**:
  - TV show search returns correct results
  - Season and episode parameters are handled correctly
  - Media kind is set to `.tvShow`

### 2. Multi-Provider Tests

#### `testMultiProviderSearch()`
- **Purpose**: Verifies that multiple providers can be searched concurrently
- **What it tests**:
  - Multiple providers execute searches
  - Results from all providers are aggregated
  - Batch mode (non-incremental) works correctly

### 3. Incremental Streaming Tests

#### `testIncrementalStreaming()`
- **Purpose**: Verifies that incremental streaming delivers results as providers complete
- **What it tests**:
  - Provider callbacks are invoked as each provider completes
  - Results appear incrementally (not all at once)
  - Final completion handler receives all aggregated results
  - Fast providers deliver results before slow providers

**Key Behavior**:
- Fast provider (0.1s delay) should trigger callback first
- Slow provider (0.3s delay) should trigger callback later
- Final completion should include both providers' results

### 4. Cancellation Tests

#### `testSearchCancellation()`
- **Purpose**: Verifies that searches can be cancelled properly
- **What it tests**:
  - `Runnable.cancel()` stops ongoing searches
  - Completion handler is not called after cancellation
  - No results are returned after cancellation

**Test Strategy**:
- Start a search with a long delay (2.0s)
- Cancel immediately
- Verify no results are received

### 5. Priority Tests

#### `testProviderPriorityExecution()`
- **Purpose**: Verifies that providers execute in priority order
- **What it tests**:
  - Higher priority providers start before lower priority providers
  - Priority affects execution order (not just result ordering)

#### `testProviderPriorityResultOrdering()`
- **Purpose**: Verifies that results are ordered by provider priority
- **What it tests**:
  - Results from higher priority providers appear first
  - Priority overrides score-based ordering when priorities differ significantly

**Priority Values** (defaults):
- TMDB: 80
- TVDB: 70
- TPDB: 60

### 6. UnifiedSearchManager Integration Tests

#### `testUnifiedSearchManagerBatchMode()`
- **Purpose**: Verifies UnifiedSearchManager works in batch mode
- **What it tests**:
  - Async/await interface works correctly
  - Results are returned after all providers complete
  - Backward compatibility is maintained

#### `testUnifiedSearchManagerIncrementalMode()`
- **Purpose**: Verifies UnifiedSearchManager works in incremental mode
- **What it tests**:
  - Incremental callbacks are received
  - Final completion handler is called
  - Results are properly converted between formats

### 7. Error Handling Tests

#### `testProviderFailureHandling()`
- **Purpose**: Verifies graceful handling of provider failures
- **What it tests**:
  - One provider failing doesn't stop other providers
  - Successful providers still return results
  - Search completes successfully even with partial failures

### 8. Adult Content Filtering Tests

#### `testAdultContentFiltering()`
- **Purpose**: Verifies adult content filtering works correctly
- **What it tests**:
  - Adult providers are excluded when `includeAdult: false`
  - Normal providers still work when adult providers are filtered
  - Coordinator handles filtered provider lists correctly

## Running the Tests

### From Xcode
1. Open the project in Xcode
2. Select the test target
3. Press `Cmd+U` to run all tests
4. Or select specific test methods and run them individually

### From Command Line
```bash
# Build and test
xcodebuild test -workspace SublerPlus.xcworkspace -scheme SublerPlus -destination 'platform=macOS'

# Run specific test class
xcodebuild test -workspace SublerPlus.xcworkspace -scheme SublerPlus -destination 'platform=macOS' -only-testing:SublerPlusTests/SublerSearchArchitectureTests
```

## Test Dependencies

The tests use:
- **MockMetadataProvider**: Mock implementation of `MetadataProvider` for controlled testing
- **SublerMetadataServiceAdapter**: Converts modern providers to Subler services
- **MultiProviderSearchCoordinator**: Coordinates multi-provider searches
- **ProviderPriority**: Manages provider priority ordering

## Expected Test Results

All tests should pass when:
1. All providers are properly configured
2. Network conditions are stable (for real provider tests)
3. API keys are valid (for integration tests)

## Known Limitations

1. **Priority Execution Order**: The current implementation doesn't provide detailed execution order tracking. The test verifies that both providers execute, but exact timing may vary.

2. **Result Source Tracking**: Subler's `MetadataResult` doesn't explicitly track which provider it came from. Priority-based result ordering relies on provider name matching, which may not be 100% accurate.

3. **Cancellation Timing**: Cancellation tests use timing-based assertions which may be flaky on slower systems. Consider using more deterministic cancellation verification.

## Future Test Enhancements

1. **Performance Tests**: Measure search latency with different numbers of providers
2. **Concurrency Tests**: Verify thread safety under high concurrency
3. **Memory Tests**: Verify no memory leaks during long-running searches
4. **Integration Tests**: Test with real API providers (requires API keys)
5. **UI Tests**: Test incremental result display in the UI

## Troubleshooting

### Tests Fail to Compile
- Ensure `SublerMetadataServiceAdapter` is accessible (not `internal`)
- Check that all required imports are present
- Verify test target includes all necessary source files

### Tests Timeout
- Increase timeout values for slow network conditions
- Check that mock providers aren't blocking
- Verify cancellation is working correctly

### Priority Tests Fail
- Check that priority values are being set correctly
- Verify provider names match priority keys
- Ensure priority sorting logic is working

## Test Maintenance

When adding new features:
1. Add corresponding test cases
2. Update this documentation
3. Ensure all tests pass before merging
4. Consider adding performance benchmarks for new features

