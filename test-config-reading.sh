#!/bin/bash

# Test script to verify config reading is working correctly

CONFIG_FILE="$HOME/.ai-devkit/config.yaml"

# Source the read_config function from build-and-deploy.sh
source <(sed -n '/^read_config()/,/^}/p' build-and-deploy.sh)

echo "Testing config reading from: $CONFIG_FILE"
echo "================================================"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found. Creating test config..."
    mkdir -p "$HOME/.ai-devkit"
    cat > "$CONFIG_FILE" <<'EOF'
# Container runtime configuration (REQUIRED)
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

# Nexus configuration (OPTIONAL)
nexus:
  enabled: true
  url: "http://localhost:8081"
EOF
fi

echo "Testing container.* config keys:"
echo "---------------------------------"
echo "container.build_command: $(read_config 'container.build_command')"
echo "container.runtime: $(read_config 'container.runtime')"
echo "container.runtime_import: $(read_config 'container.runtime_import')"

echo ""
echo "Testing nexus.* config keys:"
echo "----------------------------"
echo "nexus.enabled: $(read_config 'nexus.enabled')"
echo "nexus.url: $(read_config 'nexus.url')"

echo ""
echo "Testing old format keys (should return empty):"
echo "----------------------------------------------"
echo "build_command: $(read_config 'build_command')"
echo "runtime: $(read_config 'runtime')"
echo "runtime_import: $(read_config 'runtime_import')"