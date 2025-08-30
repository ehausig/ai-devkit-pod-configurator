#!/bin/bash
# Test 4: Component Configuration Generation

echo "=== Test 4: Component Configuration Generation ==="
echo ""

echo "1. Checking Python component structure..."
if [[ -d "components/languages/python-3.11/ai-devkit" ]]; then
    echo "✅ PASS: Python component has ai-devkit directory"
    ls -la components/languages/python-3.11/ai-devkit/
else
    echo "❌ FAIL: Python component missing ai-devkit directory"
fi
echo ""

echo "2. Checking Python pip.conf generation..."
# Simulate config generation for Python
export COMPONENT_DIR="components/languages/python-3.11"
if [[ -f "$COMPONENT_DIR/ai-devkit/config.yaml" ]]; then
    FORMAT=$(yq eval '.configuration.format' "$COMPONENT_DIR/ai-devkit/config.yaml" 2>/dev/null)
    if [[ "$FORMAT" == "pypi" ]]; then
        echo "✅ PASS: Python component configured for PyPI"
    else
        echo "❌ FAIL: Python component format is '$FORMAT' (expected 'pypi')"
    fi
else
    echo "❌ FAIL: Python component missing config.yaml"
fi
echo ""

echo "3. Testing pip.conf generation in container..."
POD_NAME=$(kubectl get pods -n ai-devkit -l app=ai-devkit -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "$POD_NAME" ]]; then
    # Check if pip.conf was generated
    PIP_CONF=$(kubectl exec -n ai-devkit "$POD_NAME" -- cat /home/devuser/.config/pip/pip.conf 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "✅ PASS: pip.conf exists in container"
        echo "$PIP_CONF" | head -3
    else
        echo "⚠️  WARNING: pip.conf not found (Python might not be installed)"
    fi
else
    echo "⚠️  WARNING: No running pod to check configuration"
fi
echo ""

echo "4. Checking template processor functions..."
FUNCTIONS=("generate_pip_config_bash" "generate_npm_config_bash" "generate_maven_settings_bash")
for func in "${FUNCTIONS[@]}"; do
    if grep -q "^$func()" lib/template-processor-bash.sh; then
        echo "✅ PASS: Function $func exists"
    else
        echo "❌ FAIL: Function $func not found"
    fi
done
echo ""

echo "=== Test 4 Complete ==="