#!/bin/bash
# Import container image directly to k3s containerd
# This bypasses the need for a registry by importing images directly into the k8s.io namespace
# of containerd on the k3s node, matching the workflow of using nerdctl locally on the k3s server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Usage
usage() {
    cat <<EOF
Usage: $0 <image-name:tag>

Import a container image directly to k3s containerd.

This script:
  1. Exports the image from podman to a tar file
  2. Transfers the tar to the k3s node via kubectl
  3. Imports the tar into containerd's k8s.io namespace
  4. Verifies the image is available for kubelet to use

Examples:
  $0 myapp:latest
  $0 localhost/buildah-test:v1.0-test

Requirements:
  - kubectl configured and able to access the cluster
  - podman with the source image available locally
  - Privileges to run kubectl debug on nodes

EOF
    exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
    usage
fi

IMAGE_NAME="$1"
TAR_FILE="/tmp/$(echo "$IMAGE_NAME" | tr ':/' '_').tar"
LOADER_POD="image-loader-$$"
NODE_NAME="${K8S_NODE_NAME:-$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')}"

info "╔════════════════════════════════════════════════════════════════╗"
info "║  Import Image to k3s containerd                                ║"
info "╚════════════════════════════════════════════════════════════════╝"
echo ""
info "Image:     $IMAGE_NAME"
info "Node:      $NODE_NAME"
info "Tar file:  $TAR_FILE"
echo ""

# Step 1: Export image from podman
info "[1/5] Exporting image from podman..."
if ! podman image exists "$IMAGE_NAME"; then
    error "Image '$IMAGE_NAME' not found in podman"
    echo "Available images:"
    podman images --format "table {{.Repository}}:{{.Tag}}"
    exit 1
fi

podman save "$IMAGE_NAME" -o "$TAR_FILE"
TAR_SIZE=$(du -h "$TAR_FILE" | cut -f1)
success "Exported image to $TAR_FILE ($TAR_SIZE)"

# Step 2: Create loader pod with host /tmp mounted
info "[2/5] Creating loader pod with host access..."
kubectl delete pod "$LOADER_POD" 2>/dev/null || true
kubectl run "$LOADER_POD" --image=alpine --restart=Never --overrides="{
  \"spec\": {
    \"hostPID\": true,
    \"hostNetwork\": true,
    \"containers\": [{
      \"name\": \"loader\",
      \"image\": \"alpine\",
      \"command\": [\"sleep\", \"3600\"],
      \"stdin\": true,
      \"tty\": true,
      \"securityContext\": {\"privileged\": true},
      \"volumeMounts\": [{
        \"name\": \"host-tmp\",
        \"mountPath\": \"/host-tmp\"
      }]
    }],
    \"volumes\": [{
      \"name\": \"host-tmp\",
      \"hostPath\": {\"path\": \"/tmp\"}
    }]
  }
}" > /dev/null

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/"$LOADER_POD" --timeout=60s > /dev/null
success "Loader pod created"

# Cleanup function
cleanup() {
    info "Cleaning up..."
    rm -f "$TAR_FILE"
    kubectl delete pod "$LOADER_POD" --force --grace-period=0 2>/dev/null || true
    # Clean up kubectl debug pods (node-debugger-*)
    kubectl delete pod -l app=kubectl-debug --field-selector status.phase=Succeeded 2>/dev/null || true
    # Fallback: delete any completed node-debugger pods
    kubectl get pods -o name | grep "node-debugger-$NODE_NAME" | xargs -r kubectl delete --force --grace-period=0 2>/dev/null || true
    success "Cleanup complete"
}
trap cleanup EXIT

# Step 3: Copy tar to node via pod
info "[3/5] Transferring tar to k3s node..."
TAR_BASENAME=$(basename "$TAR_FILE")
kubectl cp "$TAR_FILE" "$LOADER_POD:/host-tmp/$TAR_BASENAME" > /dev/null
success "Transferred $TAR_SIZE to node"

# Step 4: Import into containerd using ctr
info "[4/5] Importing into containerd (k8s.io namespace)..."

# Use kubectl debug to run ctr import on the node
# Suppress the deprecation warning with 2>&1 | grep -v deprecated
# Use k3s containerd socket at /run/k3s/containerd/containerd.sock
IMPORT_OUTPUT=$(kubectl debug node/"$NODE_NAME" -it --image=alpine -- \
  chroot /host ctr --address /run/k3s/containerd/containerd.sock --namespace k8s.io images import /tmp/"$TAR_BASENAME" 2>&1 | \
  grep -v "profile=legacy is deprecated" || true)

if echo "$IMPORT_OUTPUT" | grep -q "unpacking"; then
    success "Image imported to containerd"
else
    error "Import may have failed"
    echo "$IMPORT_OUTPUT"
fi

# Step 5: Verify image is available
info "[5/5] Verifying image in containerd..."

# Extract repository and tag from image name
REPO=$(echo "$IMAGE_NAME" | cut -d: -f1)
TAG=$(echo "$IMAGE_NAME" | cut -d: -f2)

# Check if image exists using crictl
VERIFY_OUTPUT=$(kubectl debug node/"$NODE_NAME" -it --image=alpine -- \
  chroot /host crictl --runtime-endpoint unix:///run/k3s/containerd/containerd.sock images 2>&1 | \
  grep -v "profile=legacy is deprecated" | grep -E "$REPO|IMAGE" || true)

if echo "$VERIFY_OUTPUT" | grep -q "$REPO"; then
    success "Image verified in containerd"
    echo ""
    echo "Image details:"
    echo "$VERIFY_OUTPUT" | grep -A1 "IMAGE"
    echo ""
    success "✅ Image successfully imported to k3s containerd!"
    echo ""
    info "Kubernetes can now pull this image without a registry:"
    echo "  apiVersion: v1"
    echo "  kind: Pod"
    echo "  spec:"
    echo "    containers:"
    echo "    - name: app"
    echo "      image: $IMAGE_NAME"
    echo "      imagePullPolicy: Never  # Use local containerd image"
else
    error "Image not found in containerd"
    echo "Available images:"
    echo "$VERIFY_OUTPUT"
    exit 1
fi
