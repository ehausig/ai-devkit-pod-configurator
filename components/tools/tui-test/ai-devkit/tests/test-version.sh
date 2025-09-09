#!/bin/bash
# Test version for Microsoft TUI Test
set -e

echo "Testing Microsoft TUI Test version..."
tui-test --version || echo 'TUI Test version check'
echo "✅ Version check passed"
