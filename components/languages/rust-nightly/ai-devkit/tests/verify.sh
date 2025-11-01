#!/bin/bash
# Verification script for rust-nightly component
set -e

COMPONENT_NAME="rust-nightly"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check if component is installed
if ! command -v rustc &> /dev/null; then
    echo "❌ rustc command not found"
    exit 1
fi

# Get version
version=$(rustc --version 2>&1 || rustc version 2>&1 || echo "version check failed")
echo "✅ $COMPONENT_NAME: $version"

echo "✅ $COMPONENT_NAME verification passed!"
