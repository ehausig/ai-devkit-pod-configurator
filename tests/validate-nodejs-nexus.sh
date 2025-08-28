#!/bin/bash

# Test script to validate Node.js/NPM Nexus repository configuration
# Run this inside the deployed container to verify Nexus access

set -e

echo "======================================"
echo "Node.js Nexus Repository Validation"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check npm configuration
check_npm_config() {
    echo -e "\n${YELLOW}Checking npm configuration:${NC}"
    npm config list || echo "No npm configuration found"
}

# Function to get current registry
get_current_registry() {
    npm config get registry
}

# Function to test NPM repository access
test_npm_access() {
    local repo_url="$1"
    local repo_name="$2"
    
    echo -e "\n${YELLOW}Testing $repo_name repository:${NC}"
    echo "Repository URL: $repo_url"
    
    # Try to view package info from the registry
    if npm view express --registry "$repo_url" name 2>/dev/null | grep -q "express"; then
        echo -e "${GREEN}✓ Successfully connected to $repo_name${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to connect to $repo_name${NC}"
        return 1
    fi
}

# Function to test package installation
test_package_install() {
    local package="$1"
    echo -e "\n${YELLOW}Testing package installation: $package${NC}"
    
    # Create a temporary directory for test
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Initialize a minimal package.json
    echo '{"name":"test","version":"1.0.0"}' > package.json
    
    if npm install "$package" --no-save 2>&1 | tee /tmp/npm_install.log | grep -q "added"; then
        echo -e "${GREEN}✓ Successfully installed $package${NC}"
        # Show download source
        grep "http" /tmp/npm_install.log | head -5 || true
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 0
    else
        echo -e "${RED}✗ Failed to install $package${NC}"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 1
    fi
}

# Function to verify repository URL in npm config
verify_nexus_in_config() {
    echo -e "\n${YELLOW}Verifying Nexus configuration:${NC}"
    
    local current_registry=$(get_current_registry)
    echo "Current registry: $current_registry"
    
    # Check for Nexus URLs in npm configuration
    if echo "$current_registry" | grep -q "nexus\|8091\|8085\|localhost"; then
        echo -e "${GREEN}✓ Nexus repository found in npm configuration${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ No Nexus repository found in npm configuration${NC}"
        echo "Checking for scoped registries..."
        npm config list | grep "@.*:registry" || echo "No scoped registries configured"
        return 1
    fi
}

# Function to test npm search
test_npm_search() {
    echo -e "\n${YELLOW}Testing npm search functionality:${NC}"
    
    # npm search might be disabled on some Nexus instances
    if npm search express 2>&1 | grep -q "express"; then
        echo -e "${GREEN}✓ npm search working${NC}"
    else
        echo -e "${YELLOW}⚠ npm search not available (this is normal for some Nexus configurations)${NC}"
    fi
}

# Function to test publishing capability (dry-run)
test_npm_publish() {
    echo -e "\n${YELLOW}Testing npm publish capability (dry-run):${NC}"
    
    # Create a temporary package
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    cat > package.json <<EOF
{
  "name": "@test/nexus-validation-${RANDOM}",
  "version": "0.0.1",
  "description": "Test package for Nexus validation",
  "main": "index.js",
  "private": true
}
EOF
    
    echo "module.exports = {};" > index.js
    
    # Try dry-run publish to hosted repository
    if npm publish --dry-run --registry "http://nexus:8085/repository/npm-hosted/" 2>&1 | grep -q "npm notice"; then
        echo -e "${GREEN}✓ npm publish capability verified (dry-run)${NC}"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 0
    else
        echo -e "${YELLOW}⚠ npm publish not configured or requires authentication${NC}"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 1
    fi
}

# Function to check authentication
check_npm_auth() {
    echo -e "\n${YELLOW}Checking npm authentication:${NC}"
    
    if npm whoami 2>/dev/null; then
        echo -e "${GREEN}✓ Authenticated to npm registry${NC}"
    else
        echo -e "${YELLOW}⚠ Not authenticated (anonymous access)${NC}"
    fi
}

# Main test execution
main() {
    echo "Node.js version: $(node --version)"
    echo "NPM version: $(npm --version)"
    
    # Check current configuration
    check_npm_config
    
    # Verify Nexus is configured
    verify_nexus_in_config
    
    # Check authentication status
    check_npm_auth
    
    # Test repository access based on config
    current_registry=$(get_current_registry)
    
    if [[ "$current_registry" == *"nexus"* ]] || [[ "$current_registry" == *"8091"* ]]; then
        test_npm_access "$current_registry" "Configured Registry"
    else
        echo -e "${YELLOW}Testing default Nexus URLs from config:${NC}"
        test_npm_access "http://nexus:8091/repository/npm-group/" "NPM Group Repository"
        test_npm_access "http://nexus:8085/repository/npm-hosted/" "NPM Hosted Repository"
    fi
    
    # Test npm search
    test_npm_search
    
    # Test actual package installations
    echo -e "\n${YELLOW}Testing package installations:${NC}"
    test_package_install "express"
    test_package_install "axios"
    test_package_install "jest"
    
    # Test publish capability
    test_npm_publish
    
    # Summary
    echo -e "\n${GREEN}======================================"
    echo "Node.js Nexus Validation Complete"
    echo "======================================${NC}"
    
    # Check if critical tests passed
    if verify_nexus_in_config && test_npm_access "$current_registry" "Registry"; then
        echo -e "${GREEN}Core tests passed successfully!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed. Please check Nexus configuration.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"