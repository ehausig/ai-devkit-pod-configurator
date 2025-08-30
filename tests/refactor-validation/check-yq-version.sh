#!/bin/bash
# Check yq version on host and in container

echo "=== YQ Version Check ==="
echo ""

echo "1. Host system yq:"
if command -v yq &>/dev/null; then
    YQ_VERSION=$(yq --version 2>&1 || true)
    echo "   ✓ yq is installed"
    echo "   Version: $YQ_VERSION"
    
    # Check if it's the right version (mikefarah)
    if echo "$YQ_VERSION" | grep -q "mikefarah"; then
        echo "   ✓ Go-based version (mikefarah/yq)"
    elif echo "$YQ_VERSION" | grep -q "kislyuk"; then
        echo "   ⚠ Python-based version (kislyuk/yq)"
    fi
else
    echo "   ✗ yq is not installed on host"
    echo "   Note: Tests will use grep/sed fallbacks"
fi
echo ""

echo "2. Container yq:"
POD_NAME=$(kubectl get pods -n ai-devkit -l app=ai-devkit -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "$POD_NAME" ]]; then
    CONTAINER_YQ=$(kubectl exec -n ai-devkit "$POD_NAME" -- /usr/local/bin/yq --version 2>/dev/null || echo "Not found")
    echo "   Pod: $POD_NAME"
    echo "   Version: $CONTAINER_YQ"
    
    if echo "$CONTAINER_YQ" | grep -q "mikefarah"; then
        echo "   ✓ Go-based version (mikefarah/yq)"
    fi
else
    echo "   ⚠ No running pod found to check container yq"
fi
echo ""

echo "3. Test compatibility:"
echo "   • Tests work with or without yq on host"
echo "   • Tests use grep/sed for basic YAML parsing"
echo "   • Container yq used for complex validation when available"
echo ""
echo "=== Check Complete ==="