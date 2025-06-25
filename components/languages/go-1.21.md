#### Go 1.21

**Go 1.21 Features**: `min()`, `max()`, `clear()` built-ins

**Quick Start**:
- Init: `go mod init github.com/user/project`
- Run: `go run .`
- Build: `go build -o myapp`
- Test: `go test ./...`

**Table-Driven Tests**:
```go
func TestWithTable(t *testing.T) {
    tests := []struct {
        name  string
        input int
        want  int
    }{
        {"positive", 5, 10},
        {"zero", 0, 0},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Double(tt.input)
            if got != tt.want {
                t.Errorf("got %v, want %v", got, tt.want)
            }
        })
    }
}
```

**Tools**: `go fmt ./...`, `go vet ./...`, `go mod tidy`

**Error wrapping**: `fmt.Errorf("context: %w", err)`
