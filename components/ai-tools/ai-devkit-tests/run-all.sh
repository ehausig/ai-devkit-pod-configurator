#!/bin/bash
# AI DevKit Component Test Orchestrator
# This script is injected into containers to run all component tests

set -e

echo "========================================="
echo "AI DevKit Component Verification Suite"
echo "========================================="
echo ""

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
FAILED_COMPONENTS=()

# Find and run all component test directories
for test_dir in /home/devuser/.ai-devkit/tests/*/; do
    if [[ -d "$test_dir" ]]; then
        component=$(basename "$test_dir")
        TOTAL=$((TOTAL + 1))
        
        if [[ -f "$test_dir/verify.sh" ]]; then
            echo "Testing $component..."
            echo "-----------------------------------------"
            
            if bash "$test_dir/verify.sh"; then
                echo "✅ $component: PASSED"
                PASSED=$((PASSED + 1))
            else
                echo "❌ $component: FAILED"
                FAILED=$((FAILED + 1))
                FAILED_COMPONENTS+=("$component")
            fi
        else
            echo "⚠️  $component: No verify.sh found (SKIPPED)"
            SKIPPED=$((SKIPPED + 1))
        fi
        echo ""
    fi
done

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Total Components: $TOTAL"
echo "✅ Passed:       $PASSED"
echo "❌ Failed:       $FAILED"
echo "⚠️  Skipped:      $SKIPPED"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "Failed components:"
    for comp in "${FAILED_COMPONENTS[@]}"; do
        echo "  - $comp"
    done
    echo ""
    echo "Run individual tests for details:"
    echo "  ~/.ai-devkit/tests/<component>/verify.sh"
    exit 1
else
    echo ""
    echo "🎉 All component tests passed!"
    exit 0
fi