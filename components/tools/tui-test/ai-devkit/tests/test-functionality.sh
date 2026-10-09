#!/bin/bash
# Test Microsoft TUI Test functionality
set -e

echo "Testing Microsoft TUI Test setup..."

# Check if templates directory exists
if [ -d /home/devuser/.tui-test-templates ]; then
    echo "✅ TUI Test templates directory exists"
    
    # Check for template files
    if [ -f /home/devuser/.tui-test-templates/tui-test.config.ts ]; then
        echo "✅ tui-test.config.ts template found"
    else
        echo "⚠️  tui-test.config.ts template not found"
    fi
    
    if [ -f /home/devuser/.tui-test-templates/example.test.ts ]; then
        echo "✅ example.test.ts template found"
    else
        echo "⚠️  example.test.ts template not found"
    fi
else
    echo "❌ TUI Test templates directory not found"
    exit 1
fi

# Check if TUI Test command is available
if command -v tui-test &> /dev/null; then
    echo "✅ tui-test command is available"
else
    echo "❌ tui-test command not found"
    exit 1
fi

echo "✅ Microsoft TUI Test functionality check passed"
