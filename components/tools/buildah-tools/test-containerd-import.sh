#!/bin/bash
# Quick test of the containerd import workflow

set -e

echo "Building test image with podman..."
podman build -t containerd-import-test:v1 -f - <<DOCKERFILE
FROM alpine:latest
RUN echo "Test image for containerd import" > /test.txt
CMD cat /test.txt
DOCKERFILE

echo ""
echo "Importing to k3s containerd..."
/usr/local/bin/import-to-k8s-containerd.sh containerd-import-test:v1

echo ""
echo "Creating test pod to verify..."
kubectl delete pod containerd-import-test 2>/dev/null || true
kubectl run containerd-import-test --image=localhost/containerd-import-test:v1 --image-pull-policy=Never --restart=Never

echo "Waiting for pod to complete..."
kubectl wait --for=condition=Ready pod/containerd-import-test --timeout=30s || true
sleep 2

echo ""
echo "Pod logs:"
kubectl logs containerd-import-test

echo ""
echo "Cleaning up test pod..."
kubectl delete pod containerd-import-test

echo ""
echo "✅ Containerd import test successful!"
