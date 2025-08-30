#!/bin/bash
# Run all refactor validation tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

echo "=========================================="
echo "AI DevKit Refactor Validation Test Suite"
echo "=========================================="
echo ""

# Run each test in order
for test_script in "$SCRIPT_DIR"/*.sh; do
    # Skip this script itself
    if [[ "$(basename "$test_script")" == "run-all-tests.sh" ]]; then
        continue
    fi
    
    echo "Running: $(basename "$test_script")"
    echo "------------------------------------------"
    
    # Run test and capture output
    OUTPUT=$("$test_script" 2>&1)
    echo "$OUTPUT"
    
    # Count results
    PASS=$(echo "$OUTPUT" | grep -c "✅ PASS" || true)
    FAIL=$(echo "$OUTPUT" | grep -c "❌ FAIL" || true)
    WARN=$(echo "$OUTPUT" | grep -c "⚠️  WARNING" || true)
    
    PASS_COUNT=$((PASS_COUNT + PASS))
    FAIL_COUNT=$((FAIL_COUNT + FAIL))
    WARN_COUNT=$((WARN_COUNT + WARN))
    
    echo ""
done

echo "=========================================="
echo "Test Results Summary"
echo "=========================================="
echo "✅ Passed: $PASS_COUNT"
echo "❌ Failed: $FAIL_COUNT"
echo "⚠️  Warnings: $WARN_COUNT"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "🎉 All critical tests passed!"
    exit 0
else
    echo "❗ Some tests failed. Please review the output above."
    exit 1
fi