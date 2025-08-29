#!/bin/bash
# Verification script for Go 1.22 component
set -e

COMPONENT_NAME="Go 1.22"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check Go version
if ! command -v go &> /dev/null; then
    echo "❌ go command not found"
    exit 1
fi

go_version=$(go version)
if [[ ! "$go_version" =~ go1\.22 ]]; then
    echo "❌ Wrong Go version: $go_version (expected 1.22.x)"
    exit 1
fi
echo "✅ Go version: $go_version"

# Check GOPROXY environment
if [[ -f ~/.config/go-env.sh ]]; then
    source ~/.config/go-env.sh
    echo "✅ Go environment configured"
fi

if [[ -n "$GOPROXY" ]]; then
    echo "✅ GOPROXY set to: $GOPROXY"
else
    echo "⚠️  GOPROXY not set (using defaults)"
fi

# Test Go module functionality
echo "Testing Go modules..."
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"
go mod init testmodule > /dev/null 2>&1
echo 'package main
import "fmt"
func main() { fmt.Println("Hello, Go!") }' > main.go

if go build -o test main.go > /dev/null 2>&1; then
    echo "✅ Go build working"
    if ./test | grep -q "Hello, Go!"; then
        echo "✅ Go binary execution working"
    fi
else
    echo "❌ Go build failed"
    exit 1
fi

echo "✅ All Go 1.22 tests passed!"