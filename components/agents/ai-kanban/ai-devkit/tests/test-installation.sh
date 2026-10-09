#!/bin/bash
# Test installation for AI Kanban
set -e

echo "Testing AI Kanban installation..."
if command -v node &> /dev/null; then
    echo "✅ node is installed"
else
    echo "❌ node is not installed"
    exit 1
fi
