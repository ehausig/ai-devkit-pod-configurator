#!/bin/bash
# Verification script for scala-3 component
set -e

COMPONENT_NAME="scala-3"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check if component is installed
if ! command -v scala &> /dev/null; then
    echo "❌ scala command not found"
    exit 1
fi

# Get version
version=$(scala --version 2>&1 || scala version 2>&1 || echo "version check failed")
echo "✅ $COMPONENT_NAME: $version"

echo "✅ $COMPONENT_NAME verification passed!"
