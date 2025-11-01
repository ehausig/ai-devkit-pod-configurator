#!/bin/bash
# Test installation for Claude Code
set -e

echo "Testing Claude Code installation..."
if command -v claude &> /dev/null; then
    echo "✅ claude is installed"
else
    echo "❌ claude is not installed"
    exit 1
fi
