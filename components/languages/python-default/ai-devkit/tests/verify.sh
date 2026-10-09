#!/bin/bash
# Verification script for python-default component
set -e

COMPONENT_NAME="python-default"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check if component is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ python3 command not found"
    exit 1
fi

# Get version
version=$(python3 --version 2>&1 || python3 version 2>&1 || echo "version check failed")
echo "✅ $COMPONENT_NAME: $version"

echo "✅ $COMPONENT_NAME verification passed!"
