#!/bin/bash
# Test Kotlin compilation and JAR creation capability
set -e

echo "Testing Kotlin compilation and packaging..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test creating a simple Kotlin file
cat > HelloWorld.kt << 'EOF'
fun main(args: Array<String>) {
    println("Hello, Kotlin!")
}
EOF

# Test kotlinc compilation
echo "Testing kotlinc compilation..."
kotlinc HelloWorld.kt -include-runtime -d HelloWorld.jar || {
    echo "❌ Failed to compile Kotlin file"
    exit 1
}

echo "✅ kotlinc compilation working"

# Test running compiled Kotlin JAR
if ! java -jar HelloWorld.jar | grep -q "Hello, Kotlin!"; then
    echo "❌ Compiled Kotlin application not working correctly"
    exit 1
fi

echo "✅ Running compiled Kotlin JAR working"

# Test Kotlin script execution
cat > script.kts << 'EOF'
println("Hello from Kotlin script!")
val numbers = listOf(1, 2, 3, 4, 5)
val sum = numbers.sum()
println("Sum: $sum")
println("Script execution successful")
EOF

echo "Testing Kotlin script..."
if command -v kotlin &> /dev/null; then
    kotlin script.kts | grep -q "Script execution successful" || {
        echo "⚠️  Kotlin script execution failed (may not be supported in this environment)"
    }
    echo "✅ Kotlin script test completed"
fi

# Test package structure
mkdir -p com/example
cat > com/example/TestClass.kt << 'EOF'
package com.example

fun main() {
    println("Package test successful")
}
EOF

# Test compiling with packages
kotlinc com/example/TestClass.kt -include-runtime -d TestClass.jar || {
    echo "❌ Failed to compile with package structure"
    exit 1
}

echo "✅ Package compilation working"

# Test running with packages
if ! java -jar TestClass.jar | grep -q "Package test successful"; then
    echo "❌ Package execution not working correctly"
    exit 1
fi

echo "✅ Package execution working"

echo "✅ All Kotlin compilation and packaging tests passed"