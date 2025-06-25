#### Go 1.22

**What's New**: Range over integers: `for i := range 10 { }`

**Quick Start**:
- Init module: `go mod init example.com/myapp`
- Run: `go run .`
- Build: `go build -o myapp`
- Test: `go test ./...`

**Testing**:
```go
func TestFunction(t *testing.T) {
    if got := Function(); got != expected {
        t.Errorf("got %v, want %v", got, expected)
    }
}
```
- Coverage: `go test -cover ./...`
- Race detector: `go test -race ./...`

**HTTP Server (1.22 enhanced routing)**:
```go
http.HandleFunc("GET /api/users/{id}", getUserHandler)
http.HandleFunc("POST /api/users", createUserHandler)
http.ListenAndServe(":8080", nil)
```

**Tools**: `go fmt ./...`, `go vet ./...`, `go mod tidy`

**Hot reload**: `go install github.com/cosmtrek/air@latest && air`
