#!/bin/bash
# Test Python default version
set -e

echo "Checking Python version..."

# Check if python3 command exists
if ! command -v python3 &> /dev/null; then
    echo "❌ python3 command not found"
    exit 1
fi

# Check version
python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
echo "✅ Python version: $python_version"

# Check if python command exists and what it points to
if command -v python &> /dev/null; then
    python_default_version=$(python --version 2>&1 | cut -d' ' -f2)
    echo "✅ python command points to: $python_default_version"
else
    echo "⚠️  python command not found (python3 available)"
fi

echo "✅ Python environment configured correctly"