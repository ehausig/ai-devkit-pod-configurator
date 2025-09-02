#!/bin/bash
# Test script to verify ConfigMap key generation matches volume mount subPaths

set -euo pipefail

echo "Testing ConfigMap key generation and volume mount subPath matching..."
echo

# Test Python 3.11
COMPONENT_ID="PYTHON_3_11"
MOUNT_NAME="pip-config"

# Sanitize as done in volume-mount-manager.sh
SANITIZED_ID=$(echo "$COMPONENT_ID" | tr '_' '-' | tr '[:upper:]' '[:lower:]')
CONFIGMAP_KEY="${SANITIZED_ID}-${MOUNT_NAME}"
SUBPATH="${SANITIZED_ID}-${MOUNT_NAME}"

echo "Python 3.11 Component:"
echo "  Component ID: $COMPONENT_ID"
echo "  Mount Name: $MOUNT_NAME"
echo "  Sanitized ID: $SANITIZED_ID"
echo "  ConfigMap Key: $CONFIGMAP_KEY"
echo "  Volume SubPath: $SUBPATH"
echo "  Match: $([ "$CONFIGMAP_KEY" = "$SUBPATH" ] && echo "✅ YES" || echo "❌ NO")"
echo

# Test Node.js 20
COMPONENT_ID="NODEJS_20"
MOUNT_NAME="npm-config"

SANITIZED_ID=$(echo "$COMPONENT_ID" | tr '_' '-' | tr '[:upper:]' '[:lower:]')
CONFIGMAP_KEY="${SANITIZED_ID}-${MOUNT_NAME}"
SUBPATH="${SANITIZED_ID}-${MOUNT_NAME}"

echo "Node.js 20 Component:"
echo "  Component ID: $COMPONENT_ID"
echo "  Mount Name: $MOUNT_NAME"
echo "  Sanitized ID: $SANITIZED_ID"
echo "  ConfigMap Key: $CONFIGMAP_KEY"
echo "  Volume SubPath: $SUBPATH"
echo "  Match: $([ "$CONFIGMAP_KEY" = "$SUBPATH" ] && echo "✅ YES" || echo "❌ NO")"
echo

# Test Go 1.22
COMPONENT_ID="GO_1_22"
MOUNT_NAME="go-env"

SANITIZED_ID=$(echo "$COMPONENT_ID" | tr '_' '-' | tr '[:upper:]' '[:lower:]')
CONFIGMAP_KEY="${SANITIZED_ID}-${MOUNT_NAME}"
SUBPATH="${SANITIZED_ID}-${MOUNT_NAME}"

echo "Go 1.22 Component:"
echo "  Component ID: $COMPONENT_ID"
echo "  Mount Name: $MOUNT_NAME"
echo "  Sanitized ID: $SANITIZED_ID"
echo "  ConfigMap Key: $CONFIGMAP_KEY"
echo "  Volume SubPath: $SUBPATH"
echo "  Match: $([ "$CONFIGMAP_KEY" = "$SUBPATH" ] && echo "✅ YES" || echo "❌ NO")"
echo

echo "Summary: All ConfigMap keys should match their corresponding volume mount subPaths"