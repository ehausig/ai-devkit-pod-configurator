#!/bin/bash
# Test orchestrator for WebAssembly Tools component
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  WebAssembly Tools Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Run version tests
if [ -f "$TEST_DIR/test-version.sh" ]; then
    echo -e "${YELLOW}Running version tests...${NC}"
    bash "$TEST_DIR/test-version.sh"
    echo ""
fi

# Run installation tests
if [ -f "$TEST_DIR/test-installation.sh" ]; then
    echo -e "${YELLOW}Running installation tests...${NC}"
    bash "$TEST_DIR/test-installation.sh"
    echo ""
fi

# Run functionality tests
if [ -f "$TEST_DIR/test-functionality.sh" ]; then
    echo -e "${YELLOW}Running functionality tests...${NC}"
    bash "$TEST_DIR/test-functionality.sh"
    echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  All verification tests passed!${NC}"
echo -e "${GREEN}========================================${NC}"
