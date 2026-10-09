#!/bin/bash
# Test Java package installation capability
set -e

echo "Testing Java compilation and JAR creation..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test creating a simple Java file
cat > HelloWorld.java << 'EOF'
public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello, Java!");
    }
}
EOF

# Test javac compilation
echo "Testing javac compilation..."
javac HelloWorld.java || {
    echo "❌ Failed to compile Java file"
    exit 1
}

echo "✅ javac compilation working"

# Test running compiled Java
if ! java HelloWorld | grep -q "Hello, Java!"; then
    echo "❌ Compiled Java application not working correctly"
    exit 1
fi

echo "✅ Running compiled Java working"

# Test JAR creation
echo "Testing JAR creation..."
jar cf hello.jar HelloWorld.class || {
    echo "❌ Failed to create JAR file"
    exit 1
}

echo "✅ JAR creation working"

# Test running JAR
if ! java -cp hello.jar HelloWorld | grep -q "Hello, Java!"; then
    echo "❌ Running JAR not working correctly"
    exit 1
fi

echo "✅ Running JAR working"

# Test with manifest
cat > manifest.txt << 'EOF'
Main-Class: HelloWorld
EOF

jar cfm hello-with-manifest.jar manifest.txt HelloWorld.class || {
    echo "❌ Failed to create JAR with manifest"
    exit 1
}

echo "✅ JAR with manifest creation working"

# Test running JAR with manifest
if ! java -jar hello-with-manifest.jar | grep -q "Hello, Java!"; then
    echo "❌ Running JAR with manifest not working correctly"
    exit 1
fi

echo "✅ Running JAR with manifest working"

# Test creating a package structure
mkdir -p com/example
cat > com/example/TestClass.java << 'EOF'
package com.example;

public class TestClass {
    public static void main(String[] args) {
        System.out.println("Package test successful");
    }
}
EOF

# Test compiling with packages
javac com/example/TestClass.java || {
    echo "❌ Failed to compile with package structure"
    exit 1
}

echo "✅ Package compilation working"

# Test running with packages
if ! java com.example.TestClass | grep -q "Package test successful"; then
    echo "❌ Package execution not working correctly"
    exit 1
fi

echo "✅ Package execution working"

echo "✅ All Java compilation and JAR tests passed"