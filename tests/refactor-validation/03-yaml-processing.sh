#!/bin/bash
# Test 3: YAML Processing Test

# Get the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Test 3: YAML Processing ==="
echo ""

echo "1. Checking for jq usage in core scripts..."
JQ_COUNT=$(grep -r "jq\s" "$REPO_ROOT"/lib/*.sh 2>/dev/null | grep -v "# jq" | grep -v "yq" | wc -l)
if [[ $JQ_COUNT -gt 0 ]]; then
    echo "❌ FAIL: Found $JQ_COUNT jq references (should use yq for YAML)"
    grep -r "jq\s" "$REPO_ROOT"/lib/*.sh | grep -v "# jq" | grep -v "yq" | head -5
else
    echo "✅ PASS: No jq usage found in lib scripts"
fi
echo ""

echo "2. Checking yq usage in template processor..."
if grep -q "YQ=/usr/local/bin/yq" "$REPO_ROOT"/lib/template-processor-bash.sh 2>/dev/null; then
    echo "✅ PASS: Template processor uses yq v4"
else
    echo "❌ FAIL: Template processor not configured for yq v4"
fi
echo ""

echo "3. Testing YAML parsing in container..."
POD_NAME=$(kubectl get pods -n ai-devkit -l app=ai-devkit -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "$POD_NAME" ]]; then
    # Test yq can parse YAML
    TEST_YAML='test: value
nested:
  key: data'
    
    RESULT=$(kubectl exec -n ai-devkit "$POD_NAME" -- sh -c "echo '$TEST_YAML' | /usr/local/bin/yq eval '.nested.key' -" 2>/dev/null)
    if [[ "$RESULT" == "data" ]]; then
        echo "✅ PASS: yq successfully parses YAML in container"
    else
        echo "❌ FAIL: yq failed to parse YAML (got: $RESULT)"
    fi
else
    echo "⚠️  WARNING: No running pod to test YAML parsing"
fi
echo ""

echo "4. Checking volume mount YAML handling..."
if grep -q "yq -r" "$REPO_ROOT"/lib/volume-mount-manager.sh 2>/dev/null; then
    echo "✅ PASS: Volume mount manager uses yq"
    YQ_USAGE=$(grep "yq -r" "$REPO_ROOT"/lib/volume-mount-manager.sh | wc -l)
    echo "   Found $YQ_USAGE yq operations"
else
    echo "❌ FAIL: Volume mount manager not using yq"
fi
echo ""

echo "=== Test 3 Complete ==="