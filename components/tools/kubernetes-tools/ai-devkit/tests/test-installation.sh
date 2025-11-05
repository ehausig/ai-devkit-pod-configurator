#!/bin/bash
# Test: Kubernetes Tools Installation
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing Kubernetes tools installation..."

# Check if kubectl is installed and executable
if command -v kubectl > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} kubectl is installed"
else
    echo -e "${RED}✗${NC} kubectl not found"
    exit 1
fi

# Check if helm is installed and executable
if command -v helm > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} helm is installed"
else
    echo -e "${RED}✗${NC} helm not found"
    exit 1
fi

# Check if k9s is installed and executable
if command -v k9s > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} k9s is installed"
else
    echo -e "${RED}✗${NC} k9s not found"
    exit 1
fi

# Check if kubectx is installed and executable
if command -v kubectx > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} kubectx is installed"
else
    echo -e "${RED}✗${NC} kubectx not found"
    exit 1
fi

# Check if kubens is installed and executable
if command -v kubens > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} kubens is installed"
else
    echo -e "${RED}✗${NC} kubens not found"
    exit 1
fi

# Check if stern is installed and executable
if command -v stern > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} stern is installed"
else
    echo -e "${RED}✗${NC} stern not found"
    exit 1
fi

# Check if configure-kubeconfig.sh is installed and executable
if command -v configure-kubeconfig.sh > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} configure-kubeconfig.sh is installed"
else
    echo -e "${RED}✗${NC} configure-kubeconfig.sh not found"
    exit 1
fi

echo -e "${GREEN}All installation checks passed!${NC}"
