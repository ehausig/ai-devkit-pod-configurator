#!/bin/bash
# Diagnostic script for k3s/nerdctl image issues

echo "=== K3s/nerdctl Diagnostic Script ==="
echo ""

# Check if k3s is running
echo "1. Checking K3s status..."
if systemctl is-active --quiet k3s; then
    echo "✓ K3s is running"
else
    echo "✗ K3s is not running"
    echo "  Start with: sudo systemctl start k3s"
fi
echo ""

# Check nerdctl command
echo "2. Checking nerdctl command..."
if command -v nerdctl &> /dev/null; then
    echo "✓ nerdctl is installed"
    nerdctl --version
else
    echo "✗ nerdctl not found in PATH"
fi
echo ""

# List images with full nerdctl command
echo "3. Listing images with configured command..."
echo "Command: sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io images"
sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io images
echo ""

# Check for ai-devkit image specifically
echo "4. Checking for ai-devkit image..."
if sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io images | grep -q "ai-devkit"; then
    echo "✓ ai-devkit image found"
    sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io images | grep "ai-devkit"
else
    echo "✗ ai-devkit image not found"
    echo ""
    echo "To build the image directly in k3s namespace:"
    echo "cd .build-temp"
    echo "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io build -t ai-devkit:latest ."
fi
echo ""

# Check with k3s ctr
echo "5. Double-checking with k3s ctr..."
echo "Command: sudo k3s ctr -n k8s.io images list | grep ai-devkit"
if sudo k3s ctr -n k8s.io images list | grep -q "ai-devkit"; then
    echo "✓ Image found with k3s ctr"
    sudo k3s ctr -n k8s.io images list | grep "ai-devkit"
else
    echo "✗ Image not found with k3s ctr"
fi
echo ""

# Check kubectl access
echo "6. Checking kubectl access..."
if kubectl get nodes &> /dev/null; then
    echo "✓ kubectl can access cluster"
    kubectl get nodes
else
    echo "✗ kubectl cannot access cluster"
    echo "  Check KUBECONFIG or ~/.kube/config"
fi
echo ""

echo "=== Diagnostic Complete ==="
echo ""
echo "If the image is not found, try:"
echo "1. Rebuild with: ./build-and-deploy.sh --components PYTHON_3_11"
echo "2. Or manually import: sudo k3s ctr -n k8s.io images import <image.tar>"