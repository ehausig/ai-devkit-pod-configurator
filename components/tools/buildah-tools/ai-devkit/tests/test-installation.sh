#!/bin/bash
# Test: Buildah Tools Installation
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing Buildah tools installation..."

# Check buildah
if command -v buildah &>/dev/null; then
    echo -e "${GREEN}✓${NC} buildah is installed"
else
    echo -e "${RED}✗${NC} buildah not found"
    exit 1
fi

# Check podman
if command -v podman &>/dev/null; then
    echo -e "${GREEN}✓${NC} podman is installed"
else
    echo -e "${RED}✗${NC} podman not found"
    exit 1
fi

# Check skopeo
if command -v skopeo &>/dev/null; then
    echo -e "${GREEN}✓${NC} skopeo is installed"
else
    echo -e "${RED}✗${NC} skopeo not found"
    exit 1
fi

# Check supporting tools
if command -v fuse-overlayfs &>/dev/null; then
    echo -e "${GREEN}✓${NC} fuse-overlayfs is installed"
else
    echo -e "${RED}✗${NC} fuse-overlayfs not found"
    exit 1
fi

if command -v slirp4netns &>/dev/null; then
    echo -e "${GREEN}✓${NC} slirp4netns is installed"
else
    echo -e "${RED}✗${NC} slirp4netns not found"
    exit 1
fi

echo -e "${GREEN}All tools installed successfully!${NC}"
