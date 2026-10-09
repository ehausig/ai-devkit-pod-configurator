#!/bin/bash
# Test: WebAssembly Tools Installation Check
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing installation..."

# Check if wash is installed and executable
if command -v wash > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} wash is installed"
else
    echo -e "${RED}✗${NC} wash not found"
    exit 1
fi

# Check if wasm-tools is installed and executable
if command -v wasm-tools > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} wasm-tools is installed"
else
    echo -e "${RED}✗${NC} wasm-tools not found"
    exit 1
fi

# Check if wasmtime is installed and executable
if command -v wasmtime > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} wasmtime is installed"
else
    echo -e "${RED}✗${NC} wasmtime not found"
    exit 1
fi

# Check if wit-bindgen is installed and executable
if command -v wit-bindgen > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} wit-bindgen is installed"
else
    echo -e "${RED}✗${NC} wit-bindgen not found"
    exit 1
fi

# Check if wac is installed and executable
if command -v wac > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} wac is installed"
else
    echo -e "${RED}✗${NC} wac not found"
    exit 1
fi

echo -e "${GREEN}All installation checks passed!${NC}"
