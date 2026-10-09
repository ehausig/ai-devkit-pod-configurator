#!/bin/bash
# Verification script for Rust Stable component
set -e

COMPONENT_NAME="Rust Stable"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Check Rust version
if ! command -v rustc &> /dev/null; then
    echo "❌ rustc command not found"
    exit 1
fi

rust_version=$(rustc --version)
echo "✅ Rust version: $rust_version"

# Check Cargo
if ! command -v cargo &> /dev/null; then
    echo "❌ cargo command not found"
    exit 1
fi

cargo_version=$(cargo --version)
echo "✅ Cargo version: $cargo_version"

# Check config
if [[ -f ~/.cargo/config.toml ]]; then
    echo "✅ Cargo config exists"
else
    echo "⚠️  Cargo config not found (using defaults)"
fi

# Test Rust compilation
echo "Testing Rust compilation..."
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"
cargo init --name test_project --quiet > /dev/null 2>&1

# Test build
if cargo build --quiet 2>/dev/null; then
    echo "✅ Cargo build working"
else
    echo "❌ Cargo build failed"
    exit 1
fi

# Test run
if cargo run --quiet 2>&1 | grep -q "Hello, world!"; then
    echo "✅ Rust binary execution working"
else
    echo "❌ Rust execution failed"
    exit 1
fi

echo "✅ All Rust tests passed!"