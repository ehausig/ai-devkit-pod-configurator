#### Go 1.22

**Environment Setup**
```bash
# Go uses GOPATH/modules, no virtual env needed
go version  # Verify Go 1.22
export GO111MODULE=on  # Ensure modules enabled
```

**Project Init**
```bash
# Create new module
mkdir myproject && cd myproject
go mod init github.com/username/myproject

# Create basic structure
mkdir -p cmd/myapp internal pkg
echo "package main\n\nfunc main() {\n    println(\"Hello\")\n}" > cmd/myapp/main.go
```

**Dependencies**
```bash
# Add dependency
go get github.com/gin-gonic/gin@latest
go get github.com/stretchr/testify

# Update all dependencies
go get -u ./...

# Tidy dependencies
go mod tidy

# Vendor dependencies
go mod vendor
```

**Format & Lint**
```bash
# Format code
go fmt ./...

# Run vet for issues
go vet ./...

# Install and run golangci-lint
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
golangci-lint run
```

**Testing**
```bash
# Run all tests
go test ./...

# Verbose output
go test -v ./...

# Run specific test
go test -run TestName ./...

# With coverage
go test -cover ./...
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

**Build**
```bash
# Build for current platform
go build -o myapp cmd/myapp/main.go

# Build with optimizations
go build -ldflags="-s -w" -o myapp cmd/myapp/main.go

# Cross-compile
GOOS=linux GOARCH=amd64 go build -o myapp-linux
GOOS=windows GOARCH=amd64 go build -o myapp.exe
```

**Run**
```bash
# Run directly
go run cmd/myapp/main.go

# Run with arguments
go run cmd/myapp/main.go -flag value

# Hot reload with air
go install github.com/cosmtrek/air@latest
air

# Run built binary
./myapp
```
