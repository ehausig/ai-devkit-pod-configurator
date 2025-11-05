#!/bin/bash
# Test: WebAssembly Tools Version Check
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing WebAssembly tools versions..."

# wash version check
if wash --version 2>&1 | grep -q "wash-cli"; then
    echo -e "${GREEN}✓${NC} wash version check passed"
else
    echo -e "${RED}✗${NC} wash version incorrect or not found"
    exit 1
fi

# wasm-tools version check
if wasm-tools --version 2>&1 | grep -q "wasm-tools"; then
    echo -e "${GREEN}✓${NC} wasm-tools version check passed"
else
    echo -e "${RED}✗${NC} wasm-tools version incorrect or not found"
    exit 1
fi

# wasmtime version check
if wasmtime --version 2>&1 | grep -q "wasmtime-cli"; then
    echo -e "${GREEN}✓${NC} wasmtime version check passed"
else
    echo -e "${RED}✗${NC} wasmtime version incorrect or not found"
    exit 1
fi

# wit-bindgen version check
if wit-bindgen --version 2>&1 | grep -q "wit-bindgen"; then
    echo -e "${GREEN}✓${NC} wit-bindgen version check passed"
else
    echo -e "${RED}✗${NC} wit-bindgen version incorrect or not found"
    exit 1
fi

# wac version check
if wac --version 2>&1 | grep -q "wac"; then
    echo -e "${GREEN}✓${NC} wac version check passed"
else
    echo -e "${RED}✗${NC} wac version incorrect or not found"
    exit 1
fi

echo -e "${GREEN}All version checks passed!${NC}"
