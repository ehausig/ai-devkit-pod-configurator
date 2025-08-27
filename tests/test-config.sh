#!/bin/bash
# Test script for configuration reading

CONFIG_FILE="$HOME/.ai-devkit/config.yaml"

echo "Testing AI DevKit Configuration"
echo "================================"

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    echo ""
    echo "Please create the file with content like:"
    cat <<'EOF'
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"
EOF
    exit 1
fi

# Test yq is installed
if ! command -v yq &>/dev/null; then
    echo "ERROR: yq is not installed"
    echo "Install with: apt-get install yq"
    exit 1
fi

echo "✓ Config file exists"
echo "✓ yq is installed"
echo ""

# Test reading values with yq
echo "Testing configuration values:"
echo "----------------------------"

test_key() {
    local key="$1"
    local expected="$2"
    local value=$(yq -r ".${key} // \"\"" "$CONFIG_FILE" 2>/dev/null)
    
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
        echo "✗ $key: (empty)"
        return 1
    else
        echo "✓ $key: $value"
        if [[ -n "$expected" ]] && [[ "$value" != "$expected" ]]; then
            echo "  WARNING: Expected '$expected' but got '$value'"
        fi
        return 0
    fi
}

# Test required fields
test_key "container.build_command" || exit 1
test_key "container.runtime" || exit 1
test_key "container.runtime_import" || exit 1

echo ""
echo "Testing optional fields:"
echo "-----------------------"
test_key "nexus.enabled"
test_key "nexus.url"

echo ""
echo "Configuration test complete!"