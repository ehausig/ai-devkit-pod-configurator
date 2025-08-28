#!/bin/bash

# Test script to validate Python Nexus repository configuration
# Run this inside the deployed container to verify Nexus access

set -e

echo "==================================="
echo "Python Nexus Repository Validation"
echo "==================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check pip configuration
check_pip_config() {
    echo -e "\n${YELLOW}Checking pip configuration:${NC}"
    pip config list || echo "No pip configuration found"
}

# Function to test PyPI repository access
test_pypi_access() {
    local repo_url="$1"
    local repo_name="$2"
    
    echo -e "\n${YELLOW}Testing $repo_name repository:${NC}"
    echo "Repository URL: $repo_url"
    
    # Try to search for a common package
    if pip search requests --index "$repo_url" 2>/dev/null; then
        echo -e "${GREEN}✓ Successfully connected to $repo_name${NC}"
        return 0
    else
        # pip search is deprecated, try install dry-run instead
        if pip install --dry-run --index-url "$repo_url" requests 2>&1 | grep -q "Looking in indexes"; then
            echo -e "${GREEN}✓ Successfully connected to $repo_name${NC}"
            return 0
        else
            echo -e "${RED}✗ Failed to connect to $repo_name${NC}"
            return 1
        fi
    fi
}

# Function to test package installation
test_package_install() {
    local package="$1"
    echo -e "\n${YELLOW}Testing package installation: $package${NC}"
    
    # Create a temporary virtual environment
    temp_venv=$(mktemp -d)
    python3 -m venv "$temp_venv"
    source "$temp_venv/bin/activate"
    
    if pip install "$package" --no-cache-dir 2>&1 | tee /tmp/pip_install.log | grep -q "Successfully installed"; then
        echo -e "${GREEN}✓ Successfully installed $package${NC}"
        # Show download source
        grep "Downloading" /tmp/pip_install.log | head -5
        deactivate
        rm -rf "$temp_venv"
        return 0
    else
        echo -e "${RED}✗ Failed to install $package${NC}"
        deactivate
        rm -rf "$temp_venv"
        return 1
    fi
}

# Function to verify repository URL in pip config
verify_nexus_in_config() {
    echo -e "\n${YELLOW}Verifying Nexus configuration:${NC}"
    
    # Check for Nexus URLs in pip configuration
    if pip config list 2>/dev/null | grep -q "nexus\|8090\|8084"; then
        echo -e "${GREEN}✓ Nexus repository found in pip configuration${NC}"
        pip config list | grep -E "index-url|extra-index-url|trusted-host"
        return 0
    else
        echo -e "${YELLOW}⚠ No Nexus repository found in pip configuration${NC}"
        echo "Checking environment variables..."
        env | grep -i pip || echo "No PIP environment variables set"
        return 1
    fi
}

# Main test execution
main() {
    echo "Python version: $(python3 --version)"
    echo "Pip version: $(pip --version)"
    
    # Check current configuration
    check_pip_config
    
    # Verify Nexus is configured
    verify_nexus_in_config
    
    # Test repository access based on config
    # These URLs should match what's configured in component_repos
    if [[ -n "$PIP_INDEX_URL" ]]; then
        test_pypi_access "$PIP_INDEX_URL" "Primary index (PIP_INDEX_URL)"
    else
        echo -e "${YELLOW}Testing default Nexus URLs from config:${NC}"
        test_pypi_access "http://nexus:8090/repository/python-group/simple" "Python Group Repository"
        test_pypi_access "http://nexus:8084/repository/python-hosted/simple" "Python Hosted Repository"
    fi
    
    # Test actual package installation
    echo -e "\n${YELLOW}Testing package installations:${NC}"
    test_package_install "requests"
    test_package_install "numpy"
    test_package_install "pytest"
    
    # Summary
    echo -e "\n${GREEN}==================================="
    echo "Python Nexus Validation Complete"
    echo "===================================${NC}"
    
    # Check if any tests failed
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Some tests failed. Please check Nexus configuration.${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed successfully!${NC}"
    fi
}

# Run main function
main "$@"