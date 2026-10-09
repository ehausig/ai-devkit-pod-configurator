#!/bin/bash
# Test Python 3.11 version
set -e

echo "Checking Python 3.11 version..."

# Check if python3.11 command exists
if ! command -v python3.11 &> /dev/null; then
    echo "❌ python3.11 command not found"
    exit 1
fi

# Check version
python_version=$(python3.11 --version 2>&1 | cut -d' ' -f2)
if [[ ! "$python_version" =~ ^3\.11\. ]]; then
    echo "❌ Wrong Python version: $python_version (expected 3.11.x)"
    exit 1
fi

echo "✅ Python version: $python_version"

# Check if python3 points to python3.11
python3_version=$(python3 --version 2>&1 | cut -d' ' -f2)
if [[ "$python3_version" =~ ^3\.11\. ]]; then
    echo "✅ python3 correctly points to Python $python3_version"
else
    echo "⚠️  python3 points to Python $python3_version (not 3.11)"
fi