#!/bin/bash

CONFIG_FILE="$HOME/.ai-devkit/config.yaml"

echo "Debugging configuration reading..."
echo "================================="
echo ""

# Check if config file exists
if [[ -f "$CONFIG_FILE" ]]; then
    echo "✓ Config file exists: $CONFIG_FILE"
    echo ""
    echo "File contents:"
    echo "-------------"
    cat "$CONFIG_FILE"
    echo ""
else
    echo "✗ Config file not found: $CONFIG_FILE"
    exit 1
fi

# Source the read_config function from build-and-deploy.sh
# Extract from 'read_config() {' to the closing brace
source <(awk '/^read_config\(\) \{/,/^}/' build-and-deploy.sh)

echo "Testing config key reading:"
echo "--------------------------"

# Test reading nested keys
echo "container.build_command: '$(read_config 'container.build_command')'"
echo "container.runtime: '$(read_config 'container.runtime')'"
echo "container.runtime_import: '$(read_config 'container.runtime_import')'"

# Check if values are empty
build_cmd=$(read_config 'container.build_command')
runtime=$(read_config 'container.runtime')

echo ""
echo "Checking values:"
echo "---------------"
if [[ -z "$build_cmd" ]]; then
    echo "✗ build_cmd is empty"
else
    echo "✓ build_cmd: '$build_cmd'"
fi

if [[ -z "$runtime" ]]; then
    echo "✗ runtime is empty"
else
    echo "✓ runtime: '$runtime'"
fi

echo ""
echo "Testing command detection:"
echo "-------------------------"
if [[ "$build_cmd" == *" "* ]]; then
    echo "Detected as full command: '$build_cmd'"
    
    # Try running the command
    echo "Testing command execution:"
    if $build_cmd images &> /dev/null; then
        echo "✓ Command works"
    else
        echo "✗ Command failed (exit code: $?)"
        echo "Trying with different subcommands..."
        
        if $build_cmd version &> /dev/null 2>&1; then
            echo "  ✓ version works"
        else
            echo "  ✗ version failed"
        fi
        
        if $build_cmd --version &> /dev/null 2>&1; then
            echo "  ✓ --version works"
        else
            echo "  ✗ --version failed"
        fi
        
        if $build_cmd info &> /dev/null 2>&1; then
            echo "  ✓ info works"
        else
            echo "  ✗ info failed"
        fi
    fi
else
    echo "Detected as simple tool name: '$build_cmd'"
fi