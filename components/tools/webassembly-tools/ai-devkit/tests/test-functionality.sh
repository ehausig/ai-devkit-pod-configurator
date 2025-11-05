#!/bin/bash
# Test: WebAssembly Tools Functionality Check
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing basic functionality..."

# Test wash help command
if wash --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} wash help command works"
else
    echo -e "${RED}✗${NC} wash help command failed"
    exit 1
fi

# Test wasm-tools help command
if wasm-tools --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} wasm-tools help command works"
else
    echo -e "${RED}✗${NC} wasm-tools help command failed"
    exit 1
fi

# Test wasmtime help command
if wasmtime --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} wasmtime help command works"
else
    echo -e "${RED}✗${NC} wasmtime help command failed"
    exit 1
fi

# Test wit-bindgen help command
if wit-bindgen --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} wit-bindgen help command works"
else
    echo -e "${RED}✗${NC} wit-bindgen help command failed"
    exit 1
fi

# Test wac help command
if wac --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} wac help command works"
else
    echo -e "${RED}✗${NC} wac help command failed"
    exit 1
fi

echo -e "${GREEN}All functionality checks passed!${NC}"
