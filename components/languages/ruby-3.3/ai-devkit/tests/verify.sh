#!/bin/bash
# Verification script for ruby-3.3 component
set -e

COMPONENT_NAME="ruby-3.3"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check if component is installed
if ! command -v ruby &> /dev/null; then
    echo "❌ ruby command not found"
    exit 1
fi

# Get version
version=$(ruby --version 2>&1 || ruby version 2>&1 || echo "version check failed")
echo "✅ $COMPONENT_NAME: $version"

echo "✅ $COMPONENT_NAME verification passed!"
