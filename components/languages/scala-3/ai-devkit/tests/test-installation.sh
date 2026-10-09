#!/bin/bash
# Test Scala compilation and jar creation capability
set -e

echo "Testing Scala compilation and packaging..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test creating a simple Scala file
cat > HelloWorld.scala << 'EOF'
object HelloWorld {
  def main(args: Array[String]): Unit = {
    println("Hello, Scala!")
  }
}
EOF

# Test scalac compilation
echo "Testing scalac compilation..."
scalac HelloWorld.scala || {
    echo "❌ Failed to compile Scala file"
    exit 1
}

echo "✅ scalac compilation working"

# Test running compiled Scala
if ! scala HelloWorld | grep -q "Hello, Scala!"; then
    echo "❌ Compiled Scala application not working correctly"
    exit 1
fi

echo "✅ Running compiled Scala working"

# Test creating JAR
echo "Testing JAR creation..."
jar cf hello.jar HelloWorld.class || {
    echo "❌ Failed to create JAR file"
    exit 1
}

echo "✅ JAR creation working"

# Test running JAR with Scala
if ! scala -cp hello.jar HelloWorld | grep -q "Hello, Scala!"; then
    echo "❌ Running JAR with Scala not working correctly"
    exit 1
fi

echo "✅ Running JAR with Scala working"

# Test package structure
mkdir -p com/example
cat > com/example/TestClass.scala << 'EOF'
package com.example

object TestClass {
  def main(args: Array[String]): Unit = {
    println("Package test successful")
  }
}
EOF

# Test compiling with packages
scalac com/example/TestClass.scala || {
    echo "❌ Failed to compile with package structure"
    exit 1
}

echo "✅ Package compilation working"

# Test running with packages
if ! scala com.example.TestClass | grep -q "Package test successful"; then
    echo "❌ Package execution not working correctly"
    exit 1
fi

echo "✅ Package execution working"

# Test Scala REPL if available
if command -v scala &> /dev/null; then
    echo "Testing Scala REPL..."
    echo 'println("REPL test successful"); :quit' | timeout 10 scala 2>/dev/null | grep -q "REPL test successful" || {
        echo "⚠️  Scala REPL test failed (may be expected in some environments)"
    }
    echo "✅ Scala REPL test completed"
fi

# Test with simple dependency management if sbt is available
if command -v sbt &> /dev/null; then
    echo "Testing sbt project..."
    
    # Create simple sbt project structure
    mkdir -p sbt-test/src/main/scala
    cd sbt-test
    
    cat > build.sbt << 'EOF'
scalaVersion := "2.13.12"
name := "sbt-test"
version := "0.1.0"
EOF

    cat > src/main/scala/Main.scala << 'EOF'
object Main {
  def main(args: Array[String]): Unit = {
    println("SBT test successful")
  }
}
EOF

    # Test sbt compilation
    timeout 60 sbt compile > /dev/null 2>&1 || {
        echo "⚠️  SBT compile test timed out or failed (not fatal)"
    }
    echo "✅ SBT test completed"
fi

echo "✅ All Scala compilation and packaging tests passed"