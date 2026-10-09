#!/bin/bash
# Test package installation capability
set -e

echo "Testing package installation..."

# Determine pip command
if command -v pip3.11 &> /dev/null; then
    PIP_CMD="pip3.11"
elif command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
else
    echo "❌ No pip command found"
    exit 1
fi

# Determine python command
if command -v python3.11 &> /dev/null; then
    PYTHON_CMD="python3.11"
elif command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
else
    echo "❌ No python command found"
    exit 1
fi

# Create a temporary virtual environment for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "Creating test virtual environment..."
$PYTHON_CMD -m venv "$TEST_DIR/venv" || {
    echo "❌ Failed to create virtual environment"
    exit 1
}

# Activate venv and test installation
source "$TEST_DIR/venv/bin/activate"

# Test installing a small, commonly available package
echo "Installing test package (six)..."
pip install --no-cache-dir six > /dev/null 2>&1 || {
    echo "❌ Failed to install test package"
    deactivate
    exit 1
}

# Test that the package works
python -c "import six; print(f'six version: {six.__version__}')" || {
    echo "❌ Installed package not working"
    deactivate
    exit 1
}

deactivate
echo "✅ Package installation working"