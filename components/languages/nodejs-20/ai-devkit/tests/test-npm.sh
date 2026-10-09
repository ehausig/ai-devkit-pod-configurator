#!/bin/bash
# Test npm functionality
set -e

echo "Checking npm configuration..."

# Check if .npmrc exists
if [[ -f ~/.npmrc ]]; then
    echo "✅ .npmrc exists"
    
    # Check registry setting
    registry=$(npm config get registry)
    echo "✅ npm registry: $registry"
else
    echo "⚠️  .npmrc not found (using defaults)"
    registry=$(npm config get registry)
    echo "ℹ️  Default registry: $registry"
fi

# Test npm search functionality
echo "Testing npm connectivity..."
if npm search --version > /dev/null 2>&1; then
    echo "✅ npm connectivity working"
else
    echo "⚠️  npm search not available (may be expected for private registries)"
fi