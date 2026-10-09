#!/bin/bash
# Test Go functionality
set -e

echo "Testing Go functionality..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Initialize module
go mod init test-functionality

# Test basic Go features
echo "Testing core Go features..."

cat > main.go << 'EOF'
package main

import (
    "fmt"
    "time"
    "sync"
    "context"
    "encoding/json"
)

type Person struct {
    Name string `json:"name"`
    Age  int    `json:"age"`
}

func main() {
    // Test basic types and functions
    fmt.Println("✅ Basic I/O working")
    
    // Test structs and JSON
    p := Person{Name: "Test User", Age: 30}
    jsonData, err := json.Marshal(p)
    if err != nil {
        panic("JSON marshal failed")
    }
    
    var p2 Person
    if err := json.Unmarshal(jsonData, &p2); err != nil {
        panic("JSON unmarshal failed")
    }
    fmt.Printf("✅ JSON marshalling: %+v\n", p2)
    
    // Test goroutines and channels
    ch := make(chan string, 1)
    var wg sync.WaitGroup
    
    wg.Add(1)
    go func() {
        defer wg.Done()
        time.Sleep(10 * time.Millisecond)
        ch <- "goroutine message"
    }()
    
    wg.Wait()
    message := <-ch
    fmt.Printf("✅ Goroutines and channels: %s\n", message)
    
    // Test context
    ctx, cancel := context.WithTimeout(context.Background(), time.Second)
    defer cancel()
    
    select {
    case <-ctx.Done():
        fmt.Println("✅ Context timeout working")
    case <-time.After(2 * time.Second):
        fmt.Println("❌ Context timeout not working")
    }
    
    // Test interfaces
    var i interface{} = "test string"
    if str, ok := i.(string); ok {
        fmt.Printf("✅ Type assertion: %s\n", str)
    }
    
    // Test slices and maps
    numbers := []int{1, 2, 3, 4, 5}
    doubled := make([]int, len(numbers))
    for i, n := range numbers {
        doubled[i] = n * 2
    }
    fmt.Printf("✅ Slices and loops: %v\n", doubled)
    
    m := map[string]int{"one": 1, "two": 2}
    fmt.Printf("✅ Maps: %v\n", m)
    
    fmt.Println("✅ All Go functionality tests passed")
}
EOF

# Test go run
echo "Testing go run..."
go run main.go || {
    echo "❌ go run failed"
    exit 1
}

# Test go test with a simple test
cat > main_test.go << 'EOF'
package main

import (
    "testing"
    "encoding/json"
)

func TestPersonJSON(t *testing.T) {
    p := Person{Name: "Test", Age: 25}
    data, err := json.Marshal(p)
    if err != nil {
        t.Fatalf("Failed to marshal: %v", err)
    }
    
    var p2 Person
    if err := json.Unmarshal(data, &p2); err != nil {
        t.Fatalf("Failed to unmarshal: %v", err)
    }
    
    if p.Name != p2.Name || p.Age != p2.Age {
        t.Errorf("Mismatch: got %+v, want %+v", p2, p)
    }
}

func BenchmarkPersonJSON(b *testing.B) {
    p := Person{Name: "Test", Age: 25}
    for i := 0; i < b.N; i++ {
        data, _ := json.Marshal(p)
        var p2 Person
        json.Unmarshal(data, &p2)
    }
}
EOF

echo "Testing go test..."
go test -v || {
    echo "❌ go test failed"
    exit 1
}

echo "✅ go test working"

# Test go fmt
echo "Testing go fmt..."
go fmt ./... || {
    echo "❌ go fmt failed"
    exit 1
}

echo "✅ go fmt working"

# Test go vet
echo "Testing go vet..."
go vet ./... || {
    echo "❌ go vet failed"
    exit 1
}

echo "✅ go vet working"

echo "✅ All Go functionality tests passed"