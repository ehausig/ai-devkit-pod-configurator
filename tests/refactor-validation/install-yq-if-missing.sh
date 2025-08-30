#!/bin/bash
# Helper script to install yq if it's missing on the test system

echo "Checking for yq installation..."

if command -v yq &>/dev/null; then
    YQ_VERSION=$(yq --version 2>&1 || true)
    echo "✓ yq is already installed"
    echo "  Version: $YQ_VERSION"
    
    # Check if it's the right version (mikefarah)
    if echo "$YQ_VERSION" | grep -q "mikefarah"; then
        echo "✓ Correct version (mikefarah/yq)"
    else
        echo "⚠️  Warning: This appears to be kislyuk/yq (Python-based)"
        echo "  The tests work better with mikefarah/yq (Go-based)"
    fi
else
    echo "✗ yq is not installed"
    echo ""
    echo "To install yq (Go version), run:"
    echo ""
    echo "  # Download and install yq v4 (mikefarah version)"
    echo "  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    echo "  sudo chmod +x /usr/local/bin/yq"
    echo ""
    echo "Or if you prefer the Python version:"
    echo "  pip install yq"
    echo ""
    echo "Note: The tests will work without yq by using grep/sed fallbacks,"
    echo "      but having yq installed provides better validation."
fi