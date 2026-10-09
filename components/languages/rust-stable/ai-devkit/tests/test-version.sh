#!/bin/bash
# Test Rust stable version
set -e

echo "Checking Rust version..."

# Check if rustc command exists
if ! command -v rustc &> /dev/null; then
    echo "❌ rustc command not found"
    exit 1
fi

# Check if cargo command exists
if ! command -v cargo &> /dev/null; then
    echo "❌ cargo command not found"
    exit 1
fi

# Check Rust version
rust_version=$(rustc --version)
echo "✅ Rust version: $rust_version"

# Check it's stable channel
if [[ "$rust_version" =~ "beta" || "$rust_version" =~ "nightly" ]]; then
    echo "❌ Expected stable Rust, got: $rust_version"
    exit 1
fi

echo "✅ Rust stable channel confirmed"

# Check Cargo version
cargo_version=$(cargo --version)
echo "✅ Cargo version: $cargo_version"

# Check rustup if available
if command -v rustup &> /dev/null; then
    rustup_version=$(rustup --version | head -n1)
    echo "✅ Rustup version: $rustup_version"
    
    # Check active toolchain
    active_toolchain=$(rustup show active-toolchain)
    echo "✅ Active toolchain: $active_toolchain"
fi

# Check for essential components
if command -v rustfmt &> /dev/null; then
    rustfmt_version=$(rustfmt --version)
    echo "✅ rustfmt: $rustfmt_version"
fi

if command -v clippy-driver &> /dev/null; then
    echo "✅ clippy available"
fi

echo "✅ Rust environment configured correctly"