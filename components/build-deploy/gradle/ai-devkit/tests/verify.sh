#!/bin/bash
# Verification script for Gradle component
set -e

COMPONENT_NAME="Gradle"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check Gradle version
if ! command -v gradle &> /dev/null; then
    echo "❌ gradle command not found"
    exit 1
fi

gradle_version=$(gradle --version 2>&1 | grep "Gradle" | head -1)
echo "✅ $gradle_version"

# Test Gradle functionality
echo "Testing Gradle project creation..."
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"
cat > build.gradle <<'EOF'
apply plugin: 'java'
repositories {
    mavenCentral()
}
dependencies {
    testImplementation 'junit:junit:4.13.2'
}
EOF

# Test dependency resolution
if gradle dependencies --quiet > /dev/null 2>&1; then
    echo "✅ Dependency resolution working"
else
    echo "❌ Failed to resolve dependencies"
    exit 1
fi

echo "✅ All Gradle tests passed!"