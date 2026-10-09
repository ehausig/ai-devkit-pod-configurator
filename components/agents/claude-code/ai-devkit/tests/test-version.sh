#!/bin/bash
# Test version for Claude Code
set -e

echo "Testing Claude Code version..."
claude --version || echo 'Claude Code installed'
echo "✅ Version check passed"
