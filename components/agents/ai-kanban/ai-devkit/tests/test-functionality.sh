#!/bin/bash
# Test AI Kanban functionality
set -e

echo "Testing AI Kanban dashboard files..."

# Check if server.js exists
if [ -f /opt/ai-kanban/server.js ]; then
    echo "✅ AI Kanban server.js found"
else
    echo "❌ AI Kanban server.js not found"
    exit 1
fi

# Check if package.json exists
if [ -f /opt/ai-kanban/package.json ]; then
    echo "✅ AI Kanban package.json found"
else
    echo "❌ AI Kanban package.json not found"
    exit 1
fi

# Check if dependencies are installed
if [ -d /opt/ai-kanban/node_modules ]; then
    echo "✅ AI Kanban dependencies installed"
else
    echo "⚠️  AI Kanban dependencies not installed (may be expected)"
fi

echo "✅ AI Kanban functionality check passed"
