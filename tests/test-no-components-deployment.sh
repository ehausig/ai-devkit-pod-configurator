#!/bin/bash
# Test script to verify deployment works with no components selected

set -e

echo "================================================================"
echo "Test: Deploy with no components selected"
echo "================================================================"

# Check if running from project root
if [[ ! -f "build-and-deploy.sh" ]]; then
    echo "ERROR: Please run this script from the project root directory"
    exit 1
fi

echo "✓ Running from project root"

# Test that the README file exists
if [[ ! -f "docker/config/ai-devkit-README.md" ]]; then
    echo "ERROR: ai-devkit-README.md not found in docker/config/"
    exit 1
fi

echo "✓ README file exists"

# Create a test build directory
TEST_DIR="test-build-$$"
mkdir -p "$TEST_DIR/docker/config"

# Test the copy operation
cp docker/config/ai-devkit-README.md "$TEST_DIR/docker/config/" 2>/dev/null
if [[ ! -f "$TEST_DIR/docker/config/ai-devkit-README.md" ]]; then
    echo "ERROR: Failed to copy README to test directory"
    rm -rf "$TEST_DIR"
    exit 1
fi

echo "✓ README copy works"

# Clean up test directory
rm -rf "$TEST_DIR"

echo ""
echo "================================================================"
echo "Pre-flight checks passed!"
echo "================================================================"
echo ""
echo "To perform a full deployment test:"
echo "1. Run: ./build-and-deploy.sh"
echo "2. When prompted, press Enter without selecting any components"
echo "3. Verify the container deploys successfully"
echo "4. Check that ~/.config/ai-devkit contains only the README"
echo ""
echo "Expected results:"
echo "- No ~/.claude directory"
echo "- No language-specific config files (.npmrc, .pip.conf, etc.)"
echo "- Only ~/.config/ai-devkit/README.md present"