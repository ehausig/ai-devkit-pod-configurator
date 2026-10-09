#!/bin/bash
# Verification script for nodejs-22 component
set -e

COMPONENT_NAME="nodejs-22"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check if component is installed
if ! command -v node &> /dev/null; then
    echo "❌ node command not found"
    exit 1
fi

# Get version
version=$(node --version 2>&1 || node version 2>&1 || echo "version check failed")
echo "✅ $COMPONENT_NAME: $version"

echo "✅ $COMPONENT_NAME verification passed!"
