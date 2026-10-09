#!/bin/bash
# Verification script for kotlin component
set -e

COMPONENT_NAME="kotlin"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check if component is installed
if ! command -v kotlinc &> /dev/null; then
    echo "❌ kotlinc command not found"
    exit 1
fi

# Get version
version=$(kotlinc --version 2>&1 || kotlinc version 2>&1 || echo "version check failed")
echo "✅ $COMPONENT_NAME: $version"

echo "✅ $COMPONENT_NAME verification passed!"
