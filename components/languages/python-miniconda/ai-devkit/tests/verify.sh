#!/bin/bash
# Verification script for python-miniconda component
set -e

COMPONENT_NAME="python-miniconda"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check if component is installed
if ! command -v conda &> /dev/null; then
    echo "❌ conda command not found"
    exit 1
fi

# Get version
version=$(conda --version 2>&1 || conda version 2>&1 || echo "version check failed")
echo "✅ $COMPONENT_NAME: $version"

echo "✅ $COMPONENT_NAME verification passed!"
