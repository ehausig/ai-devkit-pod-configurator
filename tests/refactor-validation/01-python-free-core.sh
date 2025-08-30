#!/bin/bash
# Test that Python is not present in base system

echo "=== Test 1: Python-Free Core System ==="
echo ""

echo "1. Checking for Python dependencies in lib/*.sh..."
if grep -r "python3 -c\|import jinja2" lib/*.sh 2>/dev/null; then
    echo "❌ FAIL: Found Python references in lib scripts"
else
    echo "✅ PASS: No Python references in lib scripts"
fi
echo ""

echo "2. Checking for Python in Dockerfile.base..."
if grep -E "^RUN.*python" docker/Dockerfile.base; then
    echo "❌ FAIL: Found Python installation in base Dockerfile"
else
    echo "✅ PASS: No Python installation in base Dockerfile"
fi
echo ""

echo "3. Checking yq installation in Dockerfile.base..."
if grep -q "mikefarah/yq" docker/Dockerfile.base; then
    echo "✅ PASS: Go-based yq (mikefarah) is installed"
    grep "mikefarah/yq" docker/Dockerfile.base | head -1
else
    echo "❌ FAIL: Go-based yq not found in Dockerfile"
fi
echo ""

echo "4. Testing yq in running container..."
POD_NAME=$(kubectl get pods -n ai-devkit -l app=ai-devkit -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "$POD_NAME" ]]; then
    echo "Pod found: $POD_NAME"
    YQ_VERSION=$(kubectl exec -n ai-devkit "$POD_NAME" -- /usr/local/bin/yq --version 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "✅ PASS: yq is installed and working"
        echo "   Version: $YQ_VERSION"
    else
        echo "❌ FAIL: yq not found or not working"
    fi
else
    echo "⚠️  WARNING: No running pod found to test yq"
fi
echo ""

echo "5. Checking template processor..."
if [[ -f "lib/template-processor-bash.sh" ]]; then
    echo "✅ PASS: Bash template processor exists"
    # Check it doesn't use Python
    if grep -q "python" lib/template-processor-bash.sh; then
        echo "❌ FAIL: Bash template processor contains Python references"
    else
        echo "✅ PASS: Bash template processor is Python-free"
    fi
else
    echo "❌ FAIL: Bash template processor not found"
fi
echo ""

echo "=== Test 1 Complete ==="