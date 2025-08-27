#!/bin/bash
# Test that the build-and-deploy.sh functions work correctly with the config

CONFIG_FILE="$HOME/.ai-devkit/config.yaml"

# Source the required functions from build-and-deploy.sh
# We need to define the CONFIG_FILE first
CONFIG_FILE="$HOME/.ai-devkit/config.yaml"

# Extract and source the read_config function
eval "$(awk '/^read_config\(\) \{/,/^}/' build-and-deploy.sh)"

# Extract and source the helper functions
eval "$(awk '/^get_build_command\(\) \{/,/^}/' build-and-deploy.sh)"
eval "$(awk '/^get_container_tool\(\) \{/,/^}/' build-and-deploy.sh)"
eval "$(awk '/^get_configured_runtime\(\) \{/,/^}/' build-and-deploy.sh)"
eval "$(awk '/^get_import_method\(\) \{/,/^}/' build-and-deploy.sh)"

echo "Testing build-and-deploy.sh functions"
echo "======================================"
echo ""

echo "1. Testing read_config function:"
echo "--------------------------------"
build_cmd=$(read_config "container.build_command")
runtime=$(read_config "container.runtime")
import=$(read_config "container.runtime_import")

echo "  build_command: $build_cmd"
echo "  runtime: $runtime"
echo "  runtime_import: $import"

if [[ -z "$build_cmd" ]]; then
    echo "  ❌ FAILED: build_command is empty"
    exit 1
else
    echo "  ✓ build_command is set"
fi

echo ""
echo "2. Testing get_build_command function:"
echo "--------------------------------------"
cmd=$(get_build_command)
echo "  Result: $cmd"
if [[ "$cmd" == "$build_cmd" ]]; then
    echo "  ✓ Returns correct build command"
else
    echo "  ❌ FAILED: Expected '$build_cmd' but got '$cmd'"
    exit 1
fi

echo ""
echo "3. Testing get_container_tool function:"
echo "---------------------------------------"
tool=$(get_container_tool)
echo "  Extracted tool: $tool"
if [[ "$tool" == "nerdctl" ]]; then
    echo "  ✓ Correctly extracted 'nerdctl' from command"
else
    echo "  ❌ FAILED: Expected 'nerdctl' but got '$tool'"
    exit 1
fi

echo ""
echo "4. Testing get_configured_runtime function:"
echo "-------------------------------------------"
runtime_check=$(get_configured_runtime)
echo "  Runtime: $runtime_check"
if [[ "$runtime_check" == "k3s" ]]; then
    echo "  ✓ Returns correct runtime"
else
    echo "  ❌ FAILED: Expected 'k3s' but got '$runtime_check'"
    exit 1
fi

echo ""
echo "5. Testing get_import_method function:"
echo "--------------------------------------"
method=$(get_import_method)
echo "  Import method: $method"
if [[ "$method" == "direct" ]]; then
    echo "  ✓ Returns correct import method"
else
    echo "  ❌ FAILED: Expected 'direct' but got '$method'"
    exit 1
fi

echo ""
echo "✅ All function tests passed!"