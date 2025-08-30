#!/bin/bash
# Test that library scripts can be safely sourced

echo "Testing library sourcing safety..."
echo "Current shell: $SHELL"
echo "Bash version: $BASH_VERSION"
echo ""

# Test sourcing template processor
echo "1. Testing template-processor-bash.sh..."
(
    cd "$(dirname "$0")"
    source lib/template-processor-bash.sh
    if [[ $? -eq 0 ]]; then
        echo "   ✓ Sourced successfully"
        # Check if functions are available
        if type generate_pip_config_bash &>/dev/null; then
            echo "   ✓ Function generate_pip_config_bash is available"
        else
            echo "   ✗ Function generate_pip_config_bash not found"
        fi
    else
        echo "   ✗ Failed to source"
    fi
)

echo ""
echo "2. Testing in zsh if available..."
if command -v zsh &>/dev/null; then
    zsh -c '
        cd "$(dirname "$0")"
        source lib/template-processor-bash.sh
        if [[ $? -eq 0 ]]; then
            echo "   ✓ Sourced successfully in zsh"
        else
            echo "   ✗ Failed to source in zsh"
        fi
    '
else
    echo "   ⚠ zsh not available"
fi

echo ""
echo "Test complete!"