#!/bin/bash
# Test: Buildah Tools Version Check
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing tool versions..."

# Test buildah version
if buildah --version > /dev/null 2>&1; then
    version=$(buildah --version)
    echo -e "${GREEN}✓${NC} buildah: $version"
else
    echo -e "${RED}✗${NC} buildah version check failed"
    exit 1
fi

# Test podman version
if podman --version > /dev/null 2>&1; then
    version=$(podman --version)
    echo -e "${GREEN}✓${NC} podman: $version"
else
    echo -e "${RED}✗${NC} podman version check failed"
    exit 1
fi

# Test skopeo version
if skopeo --version > /dev/null 2>&1; then
    version=$(skopeo --version)
    echo -e "${GREEN}✓${NC} skopeo: $version"
else
    echo -e "${RED}✗${NC} skopeo version check failed"
    exit 1
fi

echo -e "${GREEN}Version checks passed!${NC}"
