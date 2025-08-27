#!/bin/bash
# Integration test for configuration reading in build-and-deploy.sh

echo "Testing configuration integration with build-and-deploy.sh"
echo "=========================================================="
echo ""

# Test 1: Check if build-and-deploy.sh can read the config
echo "1. Testing config file detection:"
echo "---------------------------------"
if grep -q 'read_config "container.build_command"' build-and-deploy.sh; then
    echo "  ✓ Script uses read_config for container.build_command"
else
    echo "  ❌ Script doesn't use read_config properly"
fi

# Test 2: Verify yq can read our config
echo ""
echo "2. Direct yq test with our config:"
echo "----------------------------------"
build_cmd=$(yq -r '.container.build_command // ""' ~/.ai-devkit/config.yaml)
if [[ -n "$build_cmd" ]]; then
    echo "  ✓ yq reads build_command: $build_cmd"
else
    echo "  ❌ yq cannot read build_command"
fi

# Test 3: Check the read_config simplification
echo ""
echo "3. Checking read_config implementation:"
echo "---------------------------------------"
if grep -q 'yq -r "\.\${key\}"' build-and-deploy.sh; then
    echo "  ✓ read_config uses yq with proper syntax"
else
    echo "  ❌ read_config doesn't use yq properly"
fi

# Test 4: Verify container_exec uses the command directly
echo ""
echo "4. Checking container_exec implementation:"
echo "------------------------------------------"
if grep -A3 'container_exec()' build-and-deploy.sh | grep -q '\$build_cmd "\$@"'; then
    echo "  ✓ container_exec passes commands directly to build_cmd"
else
    echo "  ❌ container_exec doesn't use build_cmd properly"
fi

# Test 5: Check that hardcoded tool names are removed from key functions
echo ""
echo "5. Checking for hardcoded tool names:"
echo "-------------------------------------"
# Check container_exec function for hardcoded names
if sed -n '/^container_exec()/,/^}/p' build-and-deploy.sh | grep -qE 'case.*docker\"|case.*nerdctl\"|case.*podman\"'; then
    echo "  ❌ container_exec still has hardcoded tool names"
else
    echo "  ✓ container_exec doesn't have hardcoded tool names"
fi

# Check container_build function
if sed -n '/^container_build()/,/^}/p' build-and-deploy.sh | grep -qE 'docker build|nerdctl build|podman build'; then
    echo "  ❌ container_build still has hardcoded commands"
else
    echo "  ✓ container_build uses abstraction"
fi

echo ""
echo "✅ Integration test complete!"