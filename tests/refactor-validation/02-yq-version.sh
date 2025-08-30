#!/bin/bash
# Test yq version in the built container

echo "Testing yq version in ai-devkit container..."

# Option 1: Via kubectl exec if pod is running
POD_NAME=$(kubectl get pods -n ai-devkit -l app=ai-devkit -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "$POD_NAME" ]]; then
    echo "Using kubectl exec on pod: $POD_NAME"
    kubectl exec -n ai-devkit "$POD_NAME" -- /usr/local/bin/yq --version
else
    echo "No running pod found, trying nerdctl..."
    # Option 2: Via nerdctl run
    sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io run --rm ai-devkit:latest /usr/local/bin/yq --version
fi