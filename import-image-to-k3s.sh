#!/bin/bash

# Helper script to manually import a container image from Podman to K3s
# Usage: ./import-image-to-k3s.sh [image-name:tag]

set -e

# Default image name
IMAGE_NAME="${1:-ai-devkit:latest}"

echo "Manual image import helper for K3s"
echo "==================================="
echo ""

# Check if running with Podman and K3s
if ! command -v podman &> /dev/null; then
    echo "Error: Podman is not installed"
    exit 1
fi

if ! command -v k3s &> /dev/null; then
    echo "Error: K3s is not installed"
    exit 1
fi

# Check if image exists in Podman
echo "Step 1: Checking if image exists in Podman..."
if podman images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_NAME}$"; then
    echo "✓ Image found in Podman: $IMAGE_NAME"
else
    echo "✗ Image not found in Podman: $IMAGE_NAME"
    echo ""
    echo "Available images in Podman:"
    podman images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
    exit 1
fi

# Check current images in K3s
echo ""
echo "Step 2: Checking current images in K3s containerd..."
if sudo k3s ctr -n k8s.io images list | grep -q "$IMAGE_NAME"; then
    echo "⚠ Image already exists in K3s. Do you want to reimport? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
        echo "Skipping import."
        exit 0
    fi
    echo "Removing existing image from K3s..."
    sudo k3s ctr -n k8s.io images remove "$IMAGE_NAME" 2>/dev/null || true
fi

# Export image from Podman
echo ""
echo "Step 3: Exporting image from Podman..."
TEMP_FILE="/tmp/$(echo $IMAGE_NAME | tr ':/' '_').tar"
podman save -o "$TEMP_FILE" "$IMAGE_NAME"

if [[ ! -f "$TEMP_FILE" || ! -s "$TEMP_FILE" ]]; then
    echo "✗ Failed to export image from Podman"
    rm -f "$TEMP_FILE"
    exit 1
fi

FILE_SIZE=$(du -h "$TEMP_FILE" | cut -f1)
echo "✓ Exported image to $TEMP_FILE ($FILE_SIZE)"

# Import into K3s
echo ""
echo "Step 4: Importing image into K3s containerd..."
echo "This may take a moment for large images..."

if sudo k3s ctr -n k8s.io images import "$TEMP_FILE"; then
    echo "✓ Image imported successfully"
else
    echo "✗ Failed to import image into K3s"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Clean up temp file
rm -f "$TEMP_FILE"

# Verify import
echo ""
echo "Step 5: Verifying image in K3s..."
if sudo k3s ctr -n k8s.io images list | grep -q "$IMAGE_NAME"; then
    echo "✓ Image verified in K3s containerd"
    echo ""
    echo "Image details in K3s:"
    sudo k3s ctr -n k8s.io images list | grep "$IMAGE_NAME"
else
    echo "✗ Image verification failed"
    exit 1
fi

echo ""
echo "Success! Image $IMAGE_NAME is now available in K3s"
echo ""
echo "You can now deploy your application with:"
echo "  kubectl apply -f kubernetes/"
echo ""
echo "To check pod status:"
echo "  kubectl get pods -n ai-devkit"