#!/bin/bash

echo "==================================="
echo "Go Configuration Diagnostic"
echo "==================================="
echo ""

# Check build artifacts
echo "1. Checking build temp directory:"
TEMP_DIRS=$(ls -d /tmp/ai-devkit-build-* 2>/dev/null | tail -1)
if [[ -n "$TEMP_DIRS" ]]; then
    echo "   Found: $TEMP_DIRS"
    echo "   Generated configs:"
    ls -la "$TEMP_DIRS/generated-configs/" 2>/dev/null || echo "   No generated-configs directory"
    
    if [[ -f "$TEMP_DIRS/generated-configs/go-env.sh" ]]; then
        echo ""
        echo "   go-env.sh content:"
        cat "$TEMP_DIRS/generated-configs/go-env.sh" | sed 's/^/   /'
    fi
    
    echo ""
    echo "   ConfigMap YAML:"
    if [[ -f "$TEMP_DIRS/repository-config-dynamic.yaml" ]]; then
        echo "   Found repository-config-dynamic.yaml"
        grep -A5 "go-env" "$TEMP_DIRS/repository-config-dynamic.yaml" 2>/dev/null | sed 's/^/   /'
    else
        echo "   No repository-config-dynamic.yaml found"
    fi
else
    echo "   No build temp directory found"
fi

echo ""
echo "2. Checking Kubernetes ConfigMap:"
kubectl get configmap -n ai-devkit 2>/dev/null | grep -E "NAME|repository-config" || echo "   No repository-config ConfigMap found"

if kubectl get configmap repository-config -n ai-devkit &>/dev/null; then
    echo ""
    echo "   ConfigMap data keys:"
    kubectl get configmap repository-config -n ai-devkit -o json 2>/dev/null | jq -r '.data | keys[]' | sed 's/^/   - /'
fi

echo ""
echo "3. Checking build log for Go references:"
if [[ -f "build-and-deploy.log" ]]; then
    echo "   Searching for 'go' configuration messages:"
    grep -i "go" build-and-deploy.log | grep -E "(config|generat|repository)" | head -5 | sed 's/^/   /'
else
    echo "   No build-and-deploy.log found"
fi

echo ""
echo "4. Inside container check (if deployed):"
POD=$(kubectl get pods -n ai-devkit -l app=ai-devkit -o name 2>/dev/null | head -1)
if [[ -n "$POD" ]]; then
    echo "   Pod: ${POD#pod/}"
    echo "   Checking mounted configs:"
    kubectl exec -n ai-devkit "${POD#pod/}" -- ls -la /home/devuser/.config/ 2>/dev/null | sed 's/^/   /'
    echo ""
    echo "   Checking go-env.sh:"
    kubectl exec -n ai-devkit "${POD#pod/}" -- cat /home/devuser/.config/go-env.sh 2>/dev/null || echo "   File not found in container"
    echo ""
    echo "   Current GOPROXY:"
    kubectl exec -n ai-devkit "${POD#pod/}" -- bash -c 'echo $GOPROXY' 2>/dev/null | sed 's/^/   GOPROXY=/'
else
    echo "   No pod found"
fi

echo ""
echo "==================================="
echo "End of diagnostic"
echo "==================================="