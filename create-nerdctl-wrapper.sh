#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Creating nerdctl wrapper for build script ===${NC}"
echo ""

# Create a wrapper script that matches your alias
sudo tee /usr/local/bin/nerdctl-wrapper > /dev/null << 'EOF'
#!/bin/bash
# Wrapper for nerdctl to use K3s containerd
# This matches the alias in ~/.zsh_aliases
exec sudo /usr/local/bin/nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io "$@"
EOF

sudo chmod +x /usr/local/bin/nerdctl-wrapper
echo -e "${GREEN}✓${NC} Created /usr/local/bin/nerdctl-wrapper"

# Update the AI DevKit configuration to use the wrapper
cat > ~/.ai-devkit/config.yaml << 'EOF'
# AI DevKit Container Runtime Configuration
# Updated to use nerdctl-wrapper for K3s
# To reconfigure: ./configure-container-runtime.sh

container:
  build_tool: nerdctl-wrapper
  runtime: k3s
  runtime_import: direct
EOF

echo -e "${GREEN}✓${NC} Updated ~/.ai-devkit/config.yaml to use nerdctl-wrapper"

echo ""
echo -e "${BLUE}Testing the wrapper...${NC}"
if nerdctl-wrapper version &>/dev/null; then
    echo -e "${GREEN}✓${NC} nerdctl-wrapper works!"
    nerdctl-wrapper version
else
    echo -e "${YELLOW}⚠${NC} nerdctl-wrapper test failed"
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "The build script will now use 'nerdctl-wrapper' which includes:"
echo "  - sudo permissions"
echo "  - K3s containerd socket"
echo "  - k8s.io namespace"
echo ""
echo "Run: ./build-and-deploy.sh"