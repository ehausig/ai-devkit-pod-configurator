#!/bin/bash
# Test Rust package installation capability (Cargo)
set -e

echo "Testing Rust package management with Cargo..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test cargo new
echo "Testing cargo new..."
cargo new test-project --quiet || {
    echo "❌ Failed to create new Cargo project"
    exit 1
}

echo "✅ cargo new working"

cd test-project

# Test basic build
echo "Testing cargo build..."
cargo build --quiet || {
    echo "❌ Failed to build Cargo project"
    exit 1
}

echo "✅ cargo build working"

# Test cargo run
echo "Testing cargo run..."
output=$(cargo run --quiet)
if [[ "$output" != "Hello, world!" ]]; then
    echo "❌ cargo run output unexpected: $output"
    exit 1
fi

echo "✅ cargo run working"

# Test adding a dependency
echo "Testing cargo add dependency..."
if command -v cargo-edit &> /dev/null || cargo install --list | grep -q cargo-edit; then
    # Use cargo add if available
    cargo add serde --quiet || {
        echo "❌ Failed to add dependency with cargo add"
        exit 1
    }
else
    # Manually edit Cargo.toml
    echo -e '\n[dependencies]\nserde = "1.0"' >> Cargo.toml
fi

echo "✅ Adding dependency working"

# Test building with dependency
echo "Testing build with dependencies..."
cargo build --quiet || {
    echo "❌ Failed to build with dependencies"
    exit 1
}

echo "✅ Building with dependencies working"

# Test using the dependency
cat > src/main.rs << 'EOF'
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Debug)]
struct Person {
    name: String,
    age: u32,
}

fn main() {
    let person = Person {
        name: "Test User".to_string(),
        age: 30,
    };
    
    println!("Person: {:?}", person);
    println!("Dependency usage successful");
}
EOF

echo "Testing usage of dependency..."
cargo build --quiet || {
    echo "❌ Failed to build with dependency usage"
    exit 1
}

output=$(cargo run --quiet)
if [[ "$output" != *"Dependency usage successful"* ]]; then
    echo "❌ Dependency not working correctly: $output"
    exit 1
fi

echo "✅ Dependency usage working"

# Test cargo test
cat > src/lib.rs << 'EOF'
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 3), 5);
    }
}
EOF

echo "Testing cargo test..."
cargo test --quiet || {
    echo "❌ cargo test failed"
    exit 1
}

echo "✅ cargo test working"

# Test cargo check (faster than build)
echo "Testing cargo check..."
cargo check --quiet || {
    echo "❌ cargo check failed"
    exit 1
}

echo "✅ cargo check working"

echo "✅ All Rust package management tests passed"