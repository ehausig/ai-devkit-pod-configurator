#!/bin/bash
# Verification script for Node.js 20 component
set -e

COMPONENT_NAME="Node.js 20"
TEST_DIR="$(dirname "$0")"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Run all test scripts in order
for test in "$TEST_DIR"/test-*.sh; do
    if [[ -f "$test" ]]; then
        echo ""
        echo "Running: $(basename "$test")"
        echo "-----------------------------------------"
        if bash "$test"; then
            echo "✅ $(basename "$test"): PASSED"
        else
            echo "❌ $(basename "$test"): FAILED"
            exit 1
        fi
    fi
done

echo ""
echo "========================================="
echo "✅ All $COMPONENT_NAME tests passed!"
echo "========================================="