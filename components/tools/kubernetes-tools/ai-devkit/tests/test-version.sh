#!/bin/bash
# Test: Kubernetes Tools Version Check
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing Kubernetes tools versions..."

# kubectl version check
if kubectl version --client 2>&1 | grep -q "v1.34"; then
    echo -e "${GREEN}✓${NC} kubectl version: v1.34.x"
else
    echo -e "${RED}✗${NC} kubectl version incorrect or not found"
    exit 1
fi

# helm version check
if helm version 2>&1 | grep -q "v3.19"; then
    echo -e "${GREEN}✓${NC} helm version: v3.19.x"
else
    echo -e "${RED}✗${NC} helm version incorrect or not found"
    exit 1
fi

# k9s version check
if k9s version 2>&1 | grep -q "v0.50"; then
    echo -e "${GREEN}✓${NC} k9s version: v0.50.x"
else
    echo -e "${RED}✗${NC} k9s version incorrect or not found"
    exit 1
fi

# kubectx version check
if kubectx --version 2>&1 | grep -q "0.9"; then
    echo -e "${GREEN}✓${NC} kubectx version: 0.9.x"
else
    echo -e "${RED}✗${NC} kubectx version incorrect or not found"
    exit 1
fi

# kubens version check
if kubens --version 2>&1 | grep -q "0.9"; then
    echo -e "${GREEN}✓${NC} kubens version: 0.9.x"
else
    echo -e "${RED}✗${NC} kubens version incorrect or not found"
    exit 1
fi

# stern version check
if stern --version 2>&1 | grep -q "1.33"; then
    echo -e "${GREEN}✓${NC} stern version: v1.33.x"
else
    echo -e "${RED}✗${NC} stern version incorrect or not found"
    exit 1
fi

echo -e "${GREEN}All version checks passed!${NC}"
