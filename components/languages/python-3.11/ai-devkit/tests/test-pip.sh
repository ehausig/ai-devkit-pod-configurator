#!/bin/bash
# Test pip functionality
set -e

echo "Checking pip functionality..."

# Check if pip3.11 exists
if ! command -v pip3.11 &> /dev/null; then
    # Try pip3 as fallback
    if ! command -v pip3 &> /dev/null; then
        echo "❌ Neither pip3.11 nor pip3 found"
        exit 1
    fi
    PIP_CMD="pip3"
else
    PIP_CMD="pip3.11"
fi

# Check pip version
pip_version=$($PIP_CMD --version 2>&1)
echo "✅ Found pip: $pip_version"

# Check pip configuration
if [[ -f ~/.config/pip/pip.conf ]]; then
    echo "✅ pip.conf exists"
    
    # Check if pip can read the config
    if $PIP_CMD config list > /dev/null 2>&1; then
        echo "✅ pip can read configuration"
    else
        echo "⚠️  pip config list failed (may be normal for some pip versions)"
    fi
else
    echo "⚠️  pip.conf not found (using defaults)"
fi