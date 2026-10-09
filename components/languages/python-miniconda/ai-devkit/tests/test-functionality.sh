#!/bin/bash
# Test Python functionality
set -e

echo "Testing Python functionality..."

# Determine python command
if command -v python3.11 &> /dev/null; then
    PYTHON_CMD="python3.11"
elif command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
else
    echo "❌ No python command found"
    exit 1
fi

# Test basic Python features
echo "Testing core Python features..."

# Test importing standard libraries
$PYTHON_CMD -c "
import sys
import os
import json
import urllib.request
import sqlite3
print('✅ Standard libraries working')
" || {
    echo "❌ Failed to import standard libraries"
    exit 1
}

# Test async functionality
$PYTHON_CMD -c "
import asyncio
async def test():
    return 'async works'
result = asyncio.run(test())
print(f'✅ Async functionality: {result}')
" || {
    echo "❌ Async functionality not working"
    exit 1
}

# Test f-strings and modern syntax
$PYTHON_CMD -c "
name = 'Python 3.11'
result = f'Testing {name}'
print(f'✅ F-strings working: {result}')
" || {
    echo "❌ Modern Python syntax not working"
    exit 1
}

echo "✅ All Python functionality tests passed"