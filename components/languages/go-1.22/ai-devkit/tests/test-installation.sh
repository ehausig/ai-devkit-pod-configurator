#!/bin/bash
# Test Go package installation capability
set -e

echo "Testing Go module and package management..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test go mod init
echo "Testing go mod init..."
go mod init test-module || {
    echo "❌ Failed to initialize Go module"
    exit 1
}

echo "✅ go mod init working"

# Test creating a simple Go file
cat > main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Hello, Go!")
}
EOF

# Test go build
echo "Testing go build..."
go build -o test-app main.go || {
    echo "❌ Failed to build Go application"
    exit 1
}

echo "✅ go build working"

# Test running the built application
if ! ./test-app | grep -q "Hello, Go!"; then
    echo "❌ Built application not working correctly"
    exit 1
fi

echo "✅ Built application runs correctly"

# Test go get with a common package
echo "Testing go get..."
go get github.com/google/uuid@latest || {
    echo "❌ Failed to download external package"
    exit 1
}

echo "✅ go get working"

# Test using the downloaded package
cat > main_with_dep.go << 'EOF'
package main

import (
    "fmt"
    "github.com/google/uuid"
)

func main() {
    id := uuid.New()
    fmt.Printf("Generated UUID: %s\n", id.String())
}
EOF

go build -o test-app-with-dep main_with_dep.go || {
    echo "❌ Failed to build with external dependency"
    exit 1
}

echo "✅ Building with external dependencies working"

# Test go mod tidy
go mod tidy || {
    echo "❌ go mod tidy failed"
    exit 1
}

echo "✅ go mod tidy working"

echo "✅ All Go package management tests passed"