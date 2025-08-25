#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Diagnosing nerdctl/K3s Configuration ===${NC}"
echo ""

# 1. Check how nerdctl is currently configured
echo -e "${BLUE}1. Checking nerdctl configuration:${NC}"
echo -n "   nerdctl location: "
which nerdctl 2>/dev/null || echo "not in PATH"

echo -n "   nerdctl version: "
nerdctl version 2>/dev/null | head -1 || echo "failed to get version"

echo ""
echo -e "${BLUE}2. Testing nerdctl commands:${NC}"

# Test without sudo (rootless)
echo -n "   Without sudo: "
if nerdctl version &>/dev/null; then
    echo -e "${GREEN}✓ Works${NC}"
    echo "      Using socket: $(nerdctl info 2>/dev/null | grep -i "server" -A5 | grep -i socket || echo "unknown")"
else
    echo -e "${RED}✗ Fails${NC}"
fi

# Test with sudo (rootful)
echo -n "   With sudo: "
if sudo nerdctl version &>/dev/null; then
    echo -e "${GREEN}✓ Works${NC}"
    echo "      Using socket: $(sudo nerdctl info 2>/dev/null | grep -i "server" -A5 | grep -i socket || echo "unknown")"
else
    echo -e "${RED}✗ Fails${NC}"
fi

# Test with K3s socket explicitly
echo -n "   With K3s socket: "
if sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io version &>/dev/null; then
    echo -e "${GREEN}✓ Works${NC}"
else
    echo -e "${RED}✗ Fails${NC}"
fi

echo ""
echo -e "${BLUE}3. Checking containerd status:${NC}"

# Check for rootless containerd
echo -n "   Rootless containerd: "
if [ -S "/run/user/$(id -u)/containerd-rootless/containerd.sock" ]; then
    echo -e "${GREEN}✓ Running${NC} (socket exists)"
elif systemctl --user is-active containerd &>/dev/null; then
    echo -e "${GREEN}✓ Running${NC} (systemd service)"
else
    echo -e "${YELLOW}✗ Not running${NC}"
fi

# Check K3s containerd
echo -n "   K3s containerd: "
if [ -S "/run/k3s/containerd/containerd.sock" ]; then
    echo -e "${GREEN}✓ Socket exists${NC}"
    ls -la /run/k3s/containerd/containerd.sock
else
    echo -e "${RED}✗ Socket not found${NC}"
fi

echo ""
echo -e "${BLUE}4. Checking nerdctl configuration files:${NC}"

# Check for nerdctl config
for config_path in ~/.config/nerdctl/nerdctl.toml /etc/nerdctl/nerdctl.toml; do
    if [ -f "$config_path" ]; then
        echo -e "   Found: $config_path"
        echo "   Contents:"
        cat "$config_path" | sed 's/^/      /'
    fi
done

echo ""
echo -e "${BLUE}5. Current AI DevKit configuration:${NC}"
if [ -f ~/.ai-devkit/config.yaml ]; then
    cat ~/.ai-devkit/config.yaml | grep -E "build_tool:|runtime:|runtime_import:" | sed 's/^/   /'
else
    echo "   No configuration found"
fi

echo ""
echo -e "${BLUE}6. Testing actual build command:${NC}"
# Create a minimal test Dockerfile
TEMP_DIR=$(mktemp -d)
cat > "$TEMP_DIR/Dockerfile" << 'EOF'
FROM alpine:latest
RUN echo "test build"
EOF

cd "$TEMP_DIR"

# Test the actual build command
echo "   Testing: nerdctl build -t test:latest ."
if nerdctl build -t test:latest . &>/dev/null; then
    echo -e "   ${GREEN}✓ Rootless build works${NC}"
    nerdctl rmi test:latest &>/dev/null || true
elif sudo nerdctl build -t test:latest . &>/dev/null; then
    echo -e "   ${YELLOW}⚠ Build requires sudo${NC}"
    sudo nerdctl rmi test:latest &>/dev/null || true
elif sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io build -t test:latest . &>/dev/null; then
    echo -e "   ${YELLOW}⚠ Build works with K3s socket explicitly${NC}"
    sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io rmi test:latest &>/dev/null || true
else
    echo -e "   ${RED}✗ Build failed with all methods${NC}"
fi

cd - > /dev/null
rm -rf "$TEMP_DIR"

echo ""
echo -e "${BLUE}=== Recommendations ===${NC}"
echo ""

# Provide recommendations based on findings
if nerdctl version &>/dev/null; then
    echo "✓ nerdctl works in rootless mode"
    echo ""
    echo "The error you're seeing suggests rootless containerd is not running."
    echo "To start it:"
    echo "  systemctl --user start containerd"
    echo "  # OR"
    echo "  containerd-rootless-setuptool.sh install"
    echo ""
    echo "Then retry: ./build-and-deploy.sh"
elif sudo nerdctl version &>/dev/null; then
    echo "⚠ nerdctl requires sudo (using K3s containerd)"
    echo ""
    echo "Option 1: Use sudo with nerdctl"
    echo "  Update ~/.ai-devkit/config.yaml:"
    echo "    build_tool: sudo nerdctl"
    echo ""
    echo "Option 2: Create an alias"
    echo "  echo 'alias nerdctl=\"sudo nerdctl\"' >> ~/.bashrc"
    echo "  source ~/.bashrc"
    echo ""
    echo "Option 3: Setup rootless containerd"
    echo "  containerd-rootless-setuptool.sh install"
    echo "  systemctl --user start containerd"
else
    echo "✗ nerdctl is not working properly"
    echo ""
    echo "Please verify your nerdctl and K3s installation"
fi