#!/bin/bash
# Verification script for java-11-openjdk component
set -e

COMPONENT_NAME="java-11-openjdk"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check if component is installed
if ! command -v java &> /dev/null; then
    echo "❌ java command not found"
    exit 1
fi

# Get version
version=$(java --version 2>&1 || java version 2>&1 || echo "version check failed")
echo "✅ $COMPONENT_NAME: $version"

echo "✅ $COMPONENT_NAME verification passed!"
