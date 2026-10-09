#!/bin/bash
# Verification script for Maven component
set -e

COMPONENT_NAME="Maven"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check Maven version
if ! command -v mvn &> /dev/null; then
    echo "❌ mvn command not found"
    exit 1
fi

maven_version=$(mvn --version | head -1)
echo "✅ $maven_version"

# Check settings
if [[ -f ~/.m2/settings.xml ]]; then
    echo "✅ Maven settings.xml exists"
else
    echo "⚠️  Maven settings.xml not found (using defaults)"
fi

# Test Maven functionality
echo "Testing Maven project..."
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"
cat > pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <groupId>test</groupId>
    <artifactId>test</artifactId>
    <version>1.0</version>
    <packaging>jar</packaging>
</project>
EOF

# Test dependency resolution
if mvn dependency:resolve -q > /dev/null 2>&1; then
    echo "✅ Maven dependency resolution working"
else
    echo "❌ Maven dependency resolution failed"
    exit 1
fi

# Test compilation
mkdir -p src/main/java/test
echo 'package test;
public class Main {
    public static void main(String[] args) {
        System.out.println("Maven works!");
    }
}' > src/main/java/test/Main.java

if mvn compile -q > /dev/null 2>&1; then
    echo "✅ Maven compilation working"
else
    echo "❌ Maven compilation failed"
    exit 1
fi

echo "✅ All Maven tests passed!"