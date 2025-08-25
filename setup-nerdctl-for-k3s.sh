#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Setting up nerdctl to use K3s containerd ===${NC}"
echo ""

# Create nerdctl config directory
mkdir -p ~/.config/nerdctl

# Create nerdctl configuration to use K3s containerd by default
cat > ~/.config/nerdctl/nerdctl.toml << 'EOF'
# nerdctl configuration for K3s
# This tells nerdctl to use K3s's containerd socket instead of looking for rootless
address = "/run/k3s/containerd/containerd.sock"
namespace = "k8s.io"
EOF

echo -e "${GREEN}✓${NC} Created ~/.config/nerdctl/nerdctl.toml"
echo ""

# Create an alias that includes sudo for K3s operations
echo -e "${BLUE}Creating nerdctl alias with sudo...${NC}"
if ! grep -q "alias nerdctl=" ~/.bashrc 2>/dev/null; then
    echo 'alias nerdctl="sudo nerdctl"' >> ~/.bashrc
    echo -e "${GREEN}✓${NC} Added nerdctl alias to ~/.bashrc"
else
    echo -e "${YELLOW}ℹ${NC} nerdctl alias already exists in ~/.bashrc"
fi

# Also add to current shell
alias nerdctl="sudo nerdctl"

echo ""
echo -e "${BLUE}Testing nerdctl with K3s...${NC}"
if sudo nerdctl version &>/dev/null; then
    echo -e "${GREEN}✓${NC} nerdctl can connect to K3s containerd"
    echo ""
    sudo nerdctl version
else
    echo -e "${YELLOW}⚠${NC} Still having issues connecting to K3s"
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Run: source ~/.bashrc"
echo "   (or open a new terminal)"
echo "2. Test: nerdctl images"
echo "3. Run: ./build-and-deploy.sh"
echo ""
echo "The build script will now use 'sudo nerdctl' automatically."