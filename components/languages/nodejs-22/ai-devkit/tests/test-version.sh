#!/bin/bash
# Test Node.js 22 version
set -e

echo "Checking Node.js version..."

# Check if node command exists
if ! command -v node &> /dev/null; then
    echo "❌ node command not found"
    exit 1
fi

# Check version
node_version=$(node --version)
if [[ ! "$node_version" =~ ^v22\. ]]; then
    echo "❌ Wrong Node.js version: $node_version (expected v22.x)"
    exit 1
fi

echo "✅ Node.js version: $node_version"

# Check npm version
if ! command -v npm &> /dev/null; then
    echo "❌ npm command not found"
    exit 1
fi

npm_version=$(npm --version)
echo "✅ npm version: $npm_version"