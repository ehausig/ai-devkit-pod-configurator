#!/bin/bash
# Buildah Tools - Main Verification Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Buildah Tools Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check buildah
echo -n "Checking buildah... "
if command -v buildah &>/dev/null; then
    version=$(buildah --version | awk '{print $3}')
    echo -e "${GREEN}✓${NC} installed (version $version)"
else
    echo -e "${RED}✗${NC} not found"
    exit 1
fi

# Check podman
echo -n "Checking podman... "
if command -v podman &>/dev/null; then
    version=$(podman --version | awk '{print $3}')
    echo -e "${GREEN}✓${NC} installed (version $version)"
else
    echo -e "${RED}✗${NC} not found"
    exit 1
fi

# Check skopeo
echo -n "Checking skopeo... "
if command -v skopeo &>/dev/null; then
    version=$(skopeo --version | awk '{print $3}')
    echo -e "${GREEN}✓${NC} installed (version $version)"
else
    echo -e "${RED}✗${NC} not found"
    exit 1
fi

# Check docker alias
echo -n "Checking docker alias... "
if alias docker &>/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} configured (points to podman)"
else
    echo -e "${YELLOW}⚠${NC} not configured (optional)"
fi

# Check rootless dependencies
echo -n "Checking fuse-overlayfs... "
if command -v fuse-overlayfs &>/dev/null; then
    echo -e "${GREEN}✓${NC} installed"
else
    echo -e "${RED}✗${NC} not found"
    exit 1
fi

echo -n "Checking slirp4netns... "
if command -v slirp4netns &>/dev/null; then
    echo -e "${GREEN}✓${NC} installed"
else
    echo -e "${RED}✗${NC} not found"
    exit 1
fi

# Check configuration directories
echo -n "Checking configuration directory... "
if [[ -d "$HOME/.config/containers" ]]; then
    echo -e "${GREEN}✓${NC} exists"
else
    echo -e "${RED}✗${NC} not found"
    exit 1
fi

echo -n "Checking storage directory... "
if [[ -d "$HOME/.local/share/containers" ]]; then
    echo -e "${GREEN}✓${NC} exists"
else
    echo -e "${RED}✗${NC} not found"
    exit 1
fi

# Check subuid/subgid
echo -n "Checking subuid configuration... "
if grep -q "^$(whoami):" /etc/subuid 2>/dev/null; then
    echo -e "${GREEN}✓${NC} configured"
else
    echo -e "${RED}✗${NC} not configured"
    exit 1
fi

echo -n "Checking subgid configuration... "
if grep -q "^$(whoami):" /etc/subgid 2>/dev/null; then
    echo -e "${GREEN}✓${NC} configured"
else
    echo -e "${RED}✗${NC} not configured"
    exit 1
fi

# Check configuration files
echo -n "Checking storage.conf... "
if [[ -f "$HOME/.config/containers/storage.conf" ]]; then
    echo -e "${GREEN}✓${NC} exists"
else
    echo -e "${YELLOW}⚠${NC} not found"
fi

echo -n "Checking registries.conf... "
if [[ -f "$HOME/.config/containers/registries.conf" ]]; then
    echo -e "${GREEN}✓${NC} exists"
else
    echo -e "${YELLOW}⚠${NC} not found"
fi

echo -n "Checking policy.json... "
if [[ -f "$HOME/.config/containers/policy.json" ]]; then
    echo -e "${GREEN}✓${NC} exists"
else
    echo -e "${YELLOW}⚠${NC} not found"
fi

# Check configure-buildah.sh script
echo -n "Checking configure-buildah.sh... "
if command -v configure-buildah.sh &>/dev/null; then
    echo -e "${GREEN}✓${NC} available"
else
    echo -e "${YELLOW}⚠${NC} not found in PATH"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Buildah Tools Verification Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Configure a registry: configure-buildah.sh"
echo "  2. Build an image: docker build -t myapp ."
echo "  3. Push to registry: docker push registry.example.com/myapp"
echo ""
