#!/bin/bash
# Test Claude Code functionality
set -e

echo "Testing Claude Code setup..."

# Check if Claude Code is in PATH
if [ -L /home/devuser/.npm-global/bin/claude ]; then
    echo "✅ Claude Code symlink exists"
else
    echo "❌ Claude Code symlink not found"
    exit 1
fi

# Check if .claude directory exists
if [ -d /home/devuser/.claude ]; then
    echo "✅ .claude directory exists"
else
    echo "❌ .claude directory not found"
    exit 1
fi

# Check if plugins directory exists with proper permissions
if [ -d /home/devuser/.claude/plugins ]; then
    echo "✅ .claude/plugins directory exists"
else
    echo "❌ .claude/plugins directory not found"
    exit 1
fi

# Check if scripts are linked
if [ -L /usr/local/bin/journal-log-json.sh ]; then
    echo "✅ Journal scripts are linked"
else
    echo "⚠️  Journal scripts not linked (may be expected)"
fi

echo "✅ Claude Code functionality check passed"
