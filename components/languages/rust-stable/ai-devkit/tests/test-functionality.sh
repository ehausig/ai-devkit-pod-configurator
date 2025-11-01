#!/bin/bash
# Test Rust functionality
set -e

echo "Testing Rust functionality..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Initialize Cargo project
cargo new test-functionality --quiet
cd test-functionality

# Test Rust language features
cat > src/main.rs << 'EOF'
use std::collections::HashMap;
use std::thread;
use std::time::Duration;
use std::sync::mpsc;

fn main() {
    println!("✅ Basic I/O working");
    
    // Test ownership and borrowing
    let s = String::from("Hello, Rust!");
    let len = calculate_length(&s);
    println!("✅ Ownership and borrowing: '{}' has length {}", s, len);
    
    // Test pattern matching
    let number = 42;
    match number {
        42 => println!("✅ Pattern matching: Found the answer!"),
        _ => println!("❌ Pattern matching failed"),
    }
    
    // Test enums and Options
    let some_value = Some(5);
    match some_value {
        Some(x) => println!("✅ Option handling: value is {}", x),
        None => println!("❌ Option handling failed"),
    }
    
    // Test structs and implementations
    let rect = Rectangle::new(10, 20);
    println!("✅ Structs and methods: Rectangle area is {}", rect.area());
    
    // Test collections
    let mut map = HashMap::new();
    map.insert(String::from("key1"), 10);
    map.insert(String::from("key2"), 20);
    println!("✅ Collections: HashMap working with {} entries", map.len());
    
    // Test iterators and closures
    let numbers: Vec<i32> = vec![1, 2, 3, 4, 5];
    let doubled: Vec<i32> = numbers.iter().map(|x| x * 2).collect();
    println!("✅ Iterators and closures: {:?} -> {:?}", numbers, doubled);
    
    // Test error handling
    let result = divide(10, 2);
    match result {
        Ok(value) => println!("✅ Error handling: 10/2 = {}", value),
        Err(e) => println!("❌ Error handling failed: {}", e),
    }
    
    // Test threading
    println!("Testing threads...");
    let (tx, rx) = mpsc::channel();
    
    thread::spawn(move || {
        thread::sleep(Duration::from_millis(10));
        tx.send(String::from("thread message")).unwrap();
    });
    
    let received = rx.recv().unwrap();
    println!("✅ Threading: {}", received);
    
    // Test traits
    let dog = Dog { name: String::from("Buddy") };
    println!("✅ Traits: {}", dog.speak());
    
    // Test generic functions
    let max_int = find_max(vec![1, 5, 3, 2]);
    let max_char = find_max(vec!['a', 'z', 'c']);
    println!("✅ Generics: max int = {}, max char = {}", max_int, max_char);
    
    println!("✅ All Rust functionality tests passed");
}

fn calculate_length(s: &String) -> usize {
    s.len()
}

struct Rectangle {
    width: u32,
    height: u32,
}

impl Rectangle {
    fn new(width: u32, height: u32) -> Self {
        Rectangle { width, height }
    }
    
    fn area(&self) -> u32 {
        self.width * self.height
    }
}

fn divide(a: i32, b: i32) -> Result<i32, String> {
    if b == 0 {
        Err(String::from("Division by zero"))
    } else {
        Ok(a / b)
    }
}

trait Animal {
    fn speak(&self) -> String;
}

struct Dog {
    name: String,
}

impl Animal for Dog {
    fn speak(&self) -> String {
        format!("{} says Woof!", self.name)
    }
}

fn find_max<T: PartialOrd + Clone>(list: Vec<T>) -> T {
    let mut max = list[0].clone();
    for item in list {
        if item > max {
            max = item;
        }
    }
    max
}
EOF

# Test compilation
echo "Testing Rust compilation..."
cargo build --quiet || {
    echo "❌ Failed to compile Rust functionality test"
    exit 1
}

echo "✅ Rust compilation working"

# Test execution
echo "Testing Rust execution..."
cargo run --quiet || {
    echo "❌ Failed to run Rust functionality test"
    exit 1
}

# Test with optimizations
echo "Testing release build..."
cargo build --release --quiet || {
    echo "❌ Release build failed"
    exit 1
}

echo "✅ Release build working"

# Test clippy if available
if command -v cargo-clippy &> /dev/null || cargo clippy --version &> /dev/null; then
    echo "Testing clippy..."
    cargo clippy --quiet -- -D warnings || {
        echo "⚠️  Clippy warnings found (not fatal)"
    }
    echo "✅ Clippy analysis completed"
fi

# Test rustfmt if available
if command -v rustfmt &> /dev/null; then
    echo "Testing rustfmt..."
    cargo fmt --check || {
        echo "⚠️  Code formatting could be improved (not fatal)"
    }
    echo "✅ rustfmt check completed"
fi

echo "✅ All Rust functionality tests passed"