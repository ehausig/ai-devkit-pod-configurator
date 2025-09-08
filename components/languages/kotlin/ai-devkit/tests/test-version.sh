#!/bin/bash
# Test Kotlin version
set -e

echo "Checking Kotlin version..."

# Check if kotlinc command exists
if ! command -v kotlinc &> /dev/null; then
    echo "❌ kotlinc command not found"
    exit 1
fi

# Check if kotlin command exists
if ! command -v kotlin &> /dev/null; then
    echo "❌ kotlin command not found"
    exit 1
fi

# Check Kotlin version
kotlin_version=$(kotlinc -version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
echo "✅ Kotlin version: $kotlin_version"

# Check kotlin runtime version
kotlin_runtime_version=$(kotlin -version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
echo "✅ Kotlin runtime version: $kotlin_runtime_version"

echo "✅ Kotlin environment configured correctly"