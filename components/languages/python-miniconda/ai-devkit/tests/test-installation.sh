#!/bin/bash
# Test Python miniconda package installation capability
set -e

echo "Testing conda package installation..."

# Determine python command
if command -v python &> /dev/null; then
    PYTHON_CMD="python"
elif command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
else
    echo "❌ No python command found"
    exit 1
fi

# Test conda if available
if command -v conda &> /dev/null; then
    echo "Testing conda install..."
    
    # Create temporary conda environment for testing
    ENV_NAME="test-env-$$"
    trap "conda env remove -n $ENV_NAME -y > /dev/null 2>&1 || true" EXIT
    
    conda create -n "$ENV_NAME" python=3.9 -y > /dev/null 2>&1 || {
        echo "❌ Failed to create conda environment"
        exit 1
    }
    
    echo "✅ conda environment creation working"
    
    # Activate environment and test package installation
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$ENV_NAME" || {
        echo "❌ Failed to activate conda environment"
        exit 1
    }
    
    # Install a package via conda
    conda install numpy -y > /dev/null 2>&1 || {
        echo "❌ Failed to install package via conda"
        conda deactivate
        exit 1
    }
    
    echo "✅ conda package installation working"
    
    # Test the installed package
    python -c "import numpy; print(f'numpy version: {numpy.__version__}')" || {
        echo "❌ Conda-installed package not working"
        conda deactivate
        exit 1
    }
    
    echo "✅ Conda-installed package working"
    
    conda deactivate
    
else
    echo "⚠️  conda not available, testing pip instead"
    
    # Fall back to pip testing like regular Python
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
    echo "✅ Package installation working (via pip)"
fi

echo "✅ Package management tests passed"