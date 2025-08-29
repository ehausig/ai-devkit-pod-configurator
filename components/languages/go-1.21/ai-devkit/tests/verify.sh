#!/bin/bash
# Verification script for go-1.21 component
set -e

COMPONENT_NAME="go-1.21"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check if component is installed
if ! command -v go &> /dev/null; then
    echo "❌ go command not found"
    exit 1
fi

# Get version
version=$(go --version 2>&1 || go version 2>&1 || echo "version check failed")
echo "✅ $COMPONENT_NAME: $version"

echo "✅ $COMPONENT_NAME verification passed!"
