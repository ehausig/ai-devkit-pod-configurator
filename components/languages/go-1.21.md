#### Go 1.21

**Environment Setup**
```bash
# Go uses modules, no virtual env needed
go version  # Verify Go 1.21
export GO111MODULE=on
```

**Project Init**
```bash
# Initialize module
mkdir myproject && cd myproject
go mod init github.com/username/myproject

# Standard layout
mkdir -p cmd/myapp internal pkg
echo "package main\n\nfunc main() {\n    println(\"Hello\")\n}" > cmd/myapp/main.go
```

**Dependencies**
```bash
# Add dependencies
go get github.com/gin-gonic/gin@latest
go get github.com/stretchr/testify

# Update dependencies
go get -u ./...

# Clean up go.mod
go mod tidy

# Download to cache
go mod download
```

**Format & Lint**
```bash
# Format code (built-in)
go fmt ./...

# Vet for issues
go vet ./...

# golangci-lint (comprehensive)
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
golangci-lint run
```

**Testing**
```bash
# Run all tests
go test ./...

# Verbose output
go test -v ./...

# Specific test
go test -run TestName ./...

# Coverage
go test -cover ./...
go test -coverprofile=cover.out ./...
go tool cover -html=cover.out
```

**Build**
```bash
# Build current platform
go build -o myapp cmd/myapp/main.go

# Production build
go build -ldflags="-s -w" -o myapp cmd/myapp/main.go

# Cross-compile
GOOS=linux GOARCH=amd64 go build -o myapp-linux
GOOS=windows GOARCH=amd64 go build -o myapp.exe
```

**Run**
```bash
# Run directly
go run cmd/myapp/main.go

# With arguments
go run cmd/myapp/main.go -flag value

# Hot reload
go install github.com/cosmtrek/air@latest
air

# Built binary
./myapp
```
