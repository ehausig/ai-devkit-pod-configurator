#!/bin/bash
# Test installation for Microsoft TUI Test
set -e

echo "Testing Microsoft TUI Test installation..."
if command -v tui-test &> /dev/null; then
    echo "✅ tui-test is installed"
else
    echo "❌ tui-test is not installed"
    exit 1
fi
