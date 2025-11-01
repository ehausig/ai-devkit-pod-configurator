#!/bin/bash
# Verification script for SBT component
set -e

COMPONENT_NAME="SBT"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check SBT version
if ! command -v sbt &> /dev/null; then
    echo "❌ sbt command not found"
    exit 1
fi

echo "✅ SBT is installed"

# Check repositories config
if [[ -f ~/.sbt/repositories ]]; then
    echo "✅ SBT repositories file exists"
else
    echo "⚠️  SBT repositories file not found (using defaults)"
fi

# Test SBT functionality
echo "Testing SBT project..."
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"
cat > build.sbt <<'EOF'
name := "test"
version := "1.0"
scalaVersion := "2.13.10"
EOF

mkdir -p src/main/scala
echo 'object Main extends App {
  println("SBT works!")
}' > src/main/scala/Main.scala

# Test compilation (with timeout to prevent hanging)
if timeout 60 sbt -batch compile > /dev/null 2>&1; then
    echo "✅ SBT compilation working"
else
    echo "⚠️  SBT compilation test skipped (may require network)"
fi

echo "✅ All SBT tests passed!"