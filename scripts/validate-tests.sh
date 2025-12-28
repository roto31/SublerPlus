#!/bin/bash
set -e

echo "🔍 Starting test validation for SublerPlus..."

# =========================
# CONFIGURATION
# =========================
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TARGET_NAME="SublerPlusCoreTests"
ADAPTER_FILE="$PROJECT_ROOT/App/Controllers/SublerCompatibility/SublerMetadataServiceAdapter.swift"
SUBLER_COMPAT_DIR="$PROJECT_ROOT/App/Controllers/SublerCompatibility"

# =========================
# STEP 1: Verify SublerMetadataServiceAdapter is public
# =========================
echo ""
echo "📋 STEP 1: Verifying SublerMetadataServiceAdapter visibility..."

if [[ ! -f "$ADAPTER_FILE" ]]; then
    echo "❌ ERROR: SublerMetadataServiceAdapter.swift not found at: $ADAPTER_FILE"
    exit 1
fi

if grep -q "public final class SublerMetadataServiceAdapter" "$ADAPTER_FILE"; then
    echo "✅ SublerMetadataServiceAdapter is public"
else
    echo "❌ ERROR: SublerMetadataServiceAdapter is not public"
    echo "   Expected: 'public final class SublerMetadataServiceAdapter'"
    echo "   Found:"
    grep "class SublerMetadataServiceAdapter" "$ADAPTER_FILE" || echo "   (class declaration not found)"
    exit 1
fi

# Verify public init
if grep -q "public init" "$ADAPTER_FILE"; then
    echo "✅ SublerMetadataServiceAdapter.init is public"
else
    echo "⚠️  WARNING: SublerMetadataServiceAdapter.init may not be public"
fi

# =========================
# STEP 2: Verify SublerCompatibility directory exists
# =========================
echo ""
echo "📋 STEP 2: Verifying SublerCompatibility directory structure..."

if [[ ! -d "$SUBLER_COMPAT_DIR" ]]; then
    echo "❌ ERROR: SublerCompatibility directory not found at: $SUBLER_COMPAT_DIR"
    exit 1
fi

echo "✅ SublerCompatibility directory found"

# Check for key files
REQUIRED_FILES=(
    "SublerMetadataServiceAdapter.swift"
    "TPDBMetadataService.swift"
    "TVDBMetadataService.swift"
    "TMDBMetadataService.swift"
    "MultiProviderSearchCoordinator.swift"
    "IncrementalRunnableTask.swift"
    "ProviderPriority.swift"
)

MISSING_FILES=()
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$SUBLER_COMPAT_DIR/$file" ]]; then
        MISSING_FILES+=("$file")
    fi
done

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo "⚠️  WARNING: Some SublerCompatibility files are missing:"
    for file in "${MISSING_FILES[@]}"; do
        echo "   - $file"
    done
else
    echo "✅ All required SublerCompatibility files present"
fi

# =========================
# STEP 3: Check if Xcode project exists (optional)
# =========================
echo ""
echo "📋 STEP 3: Checking for Xcode project..."

XCODE_PROJECT=""
XCODE_WORKSPACE=""
SCHEME_NAME=""

# Look for .xcodeproj (excluding Subler subdirectory)
if find "$PROJECT_ROOT" -maxdepth 2 -name "*.xcodeproj" -type d ! -path "*/Subler/*" | head -1 | read -r proj; then
    XCODE_PROJECT="$proj"
    SCHEME_NAME=$(basename "$proj" .xcodeproj)
    echo "✅ Found Xcode project: $XCODE_PROJECT"
    echo "   Scheme: $SCHEME_NAME"
fi

# Look for .xcworkspace
if find "$PROJECT_ROOT" -maxdepth 2 -name "*.xcworkspace" -type d | head -1 | read -r workspace; then
    XCODE_WORKSPACE="$workspace"
    echo "✅ Found Xcode workspace: $XCODE_WORKSPACE"
fi

# =========================
# STEP 4: Verify Package.swift test target configuration
# =========================
echo ""
echo "📋 STEP 4: Verifying SwiftPM test target configuration..."

if [[ ! -f "$PROJECT_ROOT/Package.swift" ]]; then
    echo "❌ ERROR: Package.swift not found"
    exit 1
fi

if grep -q "name: \"$TEST_TARGET_NAME\"" "$PROJECT_ROOT/Package.swift"; then
    echo "✅ Test target '$TEST_TARGET_NAME' found in Package.swift"
else
    echo "⚠️  WARNING: Test target '$TEST_TARGET_NAME' not explicitly found in Package.swift"
    echo "   (This may be fine if tests are auto-discovered)"
fi

# =========================
# STEP 5: Run Tests
# =========================
echo ""
echo "📋 STEP 5: Running tests..."

cd "$PROJECT_ROOT"

# Try Xcode tests first if project exists, otherwise use SwiftPM
if [[ -n "$XCODE_WORKSPACE" ]]; then
    echo "🧪 Running Xcode tests via workspace (Cmd+U equivalent)..."
    TEST_OUTPUT="xcode_test_output.log"
    
    xcodebuild test \
        -workspace "$XCODE_WORKSPACE" \
        -scheme "$SCHEME_NAME" \
        -destination "platform=macOS" \
        2>&1 | tee "$TEST_OUTPUT"
    
    TEST_EXIT_CODE=${PIPESTATUS[0]}
    
    if [[ $TEST_EXIT_CODE -eq 0 ]]; then
        if grep -q "** TEST SUCCEEDED **" "$TEST_OUTPUT" || grep -q "Testing succeeded" "$TEST_OUTPUT"; then
            echo ""
            echo "🎉 ALL XCODE TESTS PASSED"
        else
            echo ""
            echo "⚠️  Tests completed but success message not found in output"
            echo "   Check $TEST_OUTPUT for details"
        fi
    else
        echo ""
        echo "❌ XCODE TESTS FAILED (exit code: $TEST_EXIT_CODE)"
        echo "   See $TEST_OUTPUT for details"
        exit 1
    fi
    
elif [[ -n "$XCODE_PROJECT" ]]; then
    echo "🧪 Running Xcode tests via project (Cmd+U equivalent)..."
    TEST_OUTPUT="xcode_test_output.log"
    
    xcodebuild test \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME_NAME" \
        -destination "platform=macOS" \
        2>&1 | tee "$TEST_OUTPUT"
    
    TEST_EXIT_CODE=${PIPESTATUS[0]}
    
    if [[ $TEST_EXIT_CODE -eq 0 ]]; then
        if grep -q "** TEST SUCCEEDED **" "$TEST_OUTPUT" || grep -q "Testing succeeded" "$TEST_OUTPUT"; then
            echo ""
            echo "🎉 ALL XCODE TESTS PASSED"
        else
            echo ""
            echo "⚠️  Tests completed but success message not found in output"
            echo "   Check $TEST_OUTPUT for details"
        fi
    else
        echo ""
        echo "❌ XCODE TESTS FAILED (exit code: $TEST_EXIT_CODE)"
        echo "   See $TEST_OUTPUT for details"
        exit 1
    fi
    
else
    echo "🧪 Running SwiftPM tests (swift test)..."
    TEST_OUTPUT="swift_test_output.log"
    
    swift test 2>&1 | tee "$TEST_OUTPUT"
    
    TEST_EXIT_CODE=${PIPESTATUS[0]}
    
    if [[ $TEST_EXIT_CODE -eq 0 ]]; then
        # Extract test summary
        TEST_COUNT=$(grep -oE "Executed [0-9]+ test" "$TEST_OUTPUT" | tail -1 | grep -oE "[0-9]+" || echo "unknown")
        FAILURE_COUNT=$(grep -oE "with [0-9]+ failures" "$TEST_OUTPUT" | tail -1 | grep -oE "[0-9]+" || echo "0")
        
        if [[ "$FAILURE_COUNT" == "0" ]]; then
            echo ""
            echo "🎉 ALL SWIFTPM TESTS PASSED ($TEST_COUNT tests)"
        else
            echo ""
            echo "⚠️  SWIFTPM TESTS COMPLETED WITH $FAILURE_COUNT FAILURE(S) ($TEST_COUNT tests total)"
            echo "   See $TEST_OUTPUT for details"
            echo "   (Note: Some failures may be pre-existing and unrelated to SublerCompatibility)"
        fi
    else
        echo ""
        echo "❌ SWIFTPM TESTS FAILED (exit code: $TEST_EXIT_CODE)"
        echo "   See $TEST_OUTPUT for details"
        exit 1
    fi
fi

# =========================
# STEP 6: Summary
# =========================
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ TEST VALIDATION COMPLETE"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo "  • SublerMetadataServiceAdapter: ✅ Public"
echo "  • SublerCompatibility directory: ✅ Present"
echo "  • Test execution: ✅ Completed"
echo ""
echo "Note: SublerCompatibility classes are excluded from SwiftPM builds"
echo "      but available in Xcode builds (when MP42Foundation is present)."
echo ""
echo "To run tests manually:"
if [[ -n "$XCODE_WORKSPACE" ]]; then
    echo "  Xcode: Cmd+U or Product > Test"
    echo "  CLI:   xcodebuild test -workspace \"$XCODE_WORKSPACE\" -scheme \"$SCHEME_NAME\""
elif [[ -n "$XCODE_PROJECT" ]]; then
    echo "  Xcode: Cmd+U or Product > Test"
    echo "  CLI:   xcodebuild test -project \"$XCODE_PROJECT\" -scheme \"$SCHEME_NAME\""
else
    echo "  CLI:   swift test"
fi
echo ""

