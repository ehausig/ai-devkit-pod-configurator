#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== AI DevKit - nerdctl/K3s Setup Helper ===${NC}"
echo ""

# 1. Check if K3s is installed
echo -e "${BLUE}Checking K3s installation...${NC}"
if command -v k3s &> /dev/null; then
    echo -e "${GREEN}✓${NC} K3s is installed: $(k3s --version 2>&1 | head -1)"
    
    # Check if K3s is running
    if sudo systemctl is-active --quiet k3s; then
        echo -e "${GREEN}✓${NC} K3s service is running"
    else
        echo -e "${YELLOW}⚠${NC} K3s service is not running"
        echo "  Starting K3s..."
        sudo systemctl start k3s
        sleep 5
    fi
else
    echo -e "${RED}✗${NC} K3s is not installed"
    echo ""
    echo "Please install K3s first:"
    echo "  curl -sfL https://get.k3s.io | sh -"
    exit 1
fi

# 2. Check for nerdctl installation
echo ""
echo -e "${BLUE}Checking nerdctl installation...${NC}"

# Check various possible locations
NERDCTL_PATH=""
if command -v nerdctl &> /dev/null; then
    NERDCTL_PATH=$(which nerdctl)
    echo -e "${GREEN}✓${NC} nerdctl found at: $NERDCTL_PATH"
elif [ -f "/usr/local/bin/nerdctl" ]; then
    NERDCTL_PATH="/usr/local/bin/nerdctl"
    echo -e "${YELLOW}⚠${NC} nerdctl found at $NERDCTL_PATH but not in PATH"
elif [ -f "/opt/nerdctl/bin/nerdctl" ]; then
    NERDCTL_PATH="/opt/nerdctl/bin/nerdctl"
    echo -e "${YELLOW}⚠${NC} nerdctl found at $NERDCTL_PATH but not in PATH"
else
    echo -e "${RED}✗${NC} nerdctl is not installed"
    echo ""
    echo "Installing nerdctl..."
    
    # Download and install nerdctl
    NERDCTL_VERSION="1.7.6"
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    fi
    
    echo "  Downloading nerdctl v${NERDCTL_VERSION} for ${ARCH}..."
    curl -sL "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -xz -C /usr/local/bin
    
    if [ -f "/usr/local/bin/nerdctl" ]; then
        echo -e "${GREEN}✓${NC} nerdctl installed successfully"
        NERDCTL_PATH="/usr/local/bin/nerdctl"
    else
        echo -e "${RED}✗${NC} Failed to install nerdctl"
        exit 1
    fi
fi

# 3. Configure nerdctl to use K3s containerd
echo ""
echo -e "${BLUE}Configuring nerdctl for K3s...${NC}"

# Create nerdctl config directory
mkdir -p ~/.config/nerdctl

# Create nerdctl configuration for K3s
cat > ~/.config/nerdctl/nerdctl.toml << 'EOF'
# nerdctl configuration for K3s
address = "/run/k3s/containerd/containerd.sock"
namespace = "k8s.io"
EOF

echo -e "${GREEN}✓${NC} Created nerdctl configuration for K3s"

# 4. Test nerdctl with K3s
echo ""
echo -e "${BLUE}Testing nerdctl with K3s containerd...${NC}"

# Use sudo since K3s containerd requires root
if sudo $NERDCTL_PATH version &> /dev/null; then
    echo -e "${GREEN}✓${NC} nerdctl can connect to K3s containerd"
    echo ""
    echo "nerdctl version:"
    sudo $NERDCTL_PATH version
else
    echo -e "${YELLOW}⚠${NC} nerdctl needs sudo to access K3s containerd"
    echo ""
    echo "Checking K3s containerd socket permissions..."
    ls -la /run/k3s/containerd/containerd.sock 2>/dev/null || echo "Socket not found"
fi

# 5. Create wrapper script for nerdctl with sudo
echo ""
echo -e "${BLUE}Creating nerdctl wrapper for K3s...${NC}"

sudo tee /usr/local/bin/nerdctl-k3s > /dev/null << 'EOF'
#!/bin/bash
# Wrapper script for nerdctl with K3s
exec sudo /usr/local/bin/nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io "$@"
EOF

sudo chmod +x /usr/local/bin/nerdctl-k3s
echo -e "${GREEN}✓${NC} Created /usr/local/bin/nerdctl-k3s wrapper"

# 6. Update AI DevKit configuration
echo ""
echo -e "${BLUE}Updating AI DevKit configuration...${NC}"

# Check if we should use the wrapper or direct nerdctl
if sudo $NERDCTL_PATH --address /run/k3s/containerd/containerd.sock --namespace k8s.io version &> /dev/null; then
    echo -e "${GREEN}✓${NC} nerdctl works with K3s containerd"
    
    # Update the configuration to use the wrapper
    cat > ~/.ai-devkit/config.yaml << 'EOF'
# AI DevKit Container Runtime Configuration
# Updated by fix-nerdctl-k3s.sh
# To reconfigure: ./configure-container-runtime.sh

container:
  build_tool: nerdctl-k3s
  runtime: k3s
  runtime_import: direct
EOF
    
    echo -e "${GREEN}✓${NC} Updated ~/.ai-devkit/config.yaml to use nerdctl-k3s wrapper"
else
    echo -e "${RED}✗${NC} nerdctl still cannot connect to K3s"
    echo ""
    echo "You may need to use Docker or Podman instead."
    echo "Run: ./configure-container-runtime.sh"
fi

# 7. Final recommendations
echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. The build script will now use: nerdctl-k3s (with sudo)"
echo "2. This wrapper automatically connects to K3s containerd"
echo "3. Images built will be directly available to K3s"
echo ""
echo "To test the build:"
echo "  ./build-and-deploy.sh"
echo ""
echo "If you still have issues, you can alternatively:"
echo "  - Install Docker: sudo apt-get install docker.io"
echo "  - Install Podman: sudo apt-get install podman"
echo "  - Then run: ./configure-container-runtime.sh"