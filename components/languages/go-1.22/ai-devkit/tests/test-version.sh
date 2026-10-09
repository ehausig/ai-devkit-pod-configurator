#!/bin/bash
# Test Go 1.22 version
set -e

echo "Checking Go version..."

# Check if go command exists
if ! command -v go &> /dev/null; then
    echo "❌ go command not found"
    exit 1
fi

# Check version
go_version=$(go version 2>&1 | awk '{print $3}' | sed 's/go//')
if [[ ! "$go_version" =~ ^1\.22\. ]]; then
    echo "❌ Wrong Go version: $go_version (expected 1.22.x)"
    exit 1
fi

echo "✅ Go version: $go_version"

# Test basic go commands
if ! go help &> /dev/null; then
    echo "❌ go help command failed"
    exit 1
fi

echo "✅ go help command working"

# Check GOROOT and GOPATH
echo "✅ GOROOT: $(go env GOROOT)"
echo "✅ GOPATH: $(go env GOPATH)"
echo "✅ Go environment configured correctly"