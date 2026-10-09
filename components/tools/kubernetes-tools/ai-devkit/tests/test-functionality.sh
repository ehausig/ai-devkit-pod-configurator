#!/bin/bash
# Test: Kubernetes Tools Functionality
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing Kubernetes tools functionality..."

# Test kubectl help
if kubectl --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} kubectl help works"
else
    echo -e "${RED}✗${NC} kubectl help failed"
    exit 1
fi

# Test helm help
if helm --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} helm help works"
else
    echo -e "${RED}✗${NC} helm help failed"
    exit 1
fi

# Test k9s version (can't run interactively in test)
if k9s version > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} k9s version command works"
else
    echo -e "${RED}✗${NC} k9s version failed"
    exit 1
fi

# Test stern help
if stern --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} stern help works"
else
    echo -e "${RED}✗${NC} stern help failed"
    exit 1
fi

# Test .kube directory exists
if [[ -d "$HOME/.kube" ]]; then
    echo -e "${GREEN}✓${NC} .kube directory exists"
else
    echo -e "${RED}✗${NC} .kube directory not found"
    exit 1
fi

# Test .kube directory permissions
if [[ "$(stat -c '%U' "$HOME/.kube" 2>/dev/null || stat -f '%Su' "$HOME/.kube" 2>/dev/null)" == "$(whoami)" ]]; then
    echo -e "${GREEN}✓${NC} .kube directory has correct ownership"
else
    echo -e "${RED}✗${NC} .kube directory ownership incorrect"
    exit 1
fi

# Test configure-kubeconfig.sh help
if configure-kubeconfig.sh --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} configure-kubeconfig.sh help works"
else
    echo -e "${RED}✗${NC} configure-kubeconfig.sh help failed"
    exit 1
fi

# Test readme file exists
if [[ -f "$HOME/.kubernetes-tools-readme.txt" ]]; then
    echo -e "${GREEN}✓${NC} README file exists"
else
    echo -e "${RED}✗${NC} README file not found"
    exit 1
fi

echo -e "${GREEN}All functionality checks passed!${NC}"
