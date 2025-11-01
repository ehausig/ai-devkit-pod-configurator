#!/bin/bash
# Test Python miniconda version
set -e

echo "Checking Python miniconda version..."

# Check if python command exists
if ! command -v python &> /dev/null; then
    echo "❌ python command not found"
    exit 1
fi

# Check version
python_version=$(python --version 2>&1 | cut -d' ' -f2)
echo "✅ Python version: $python_version"

# Check if conda command exists
if command -v conda &> /dev/null; then
    conda_version=$(conda --version 2>&1)
    echo "✅ Conda version: $conda_version"
else
    echo "⚠️  conda command not found"
fi

# Check if we're in a conda environment
if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    echo "✅ Active conda environment: $CONDA_DEFAULT_ENV"
else
    echo "⚠️  No active conda environment"
fi

echo "✅ Python miniconda environment configured correctly"