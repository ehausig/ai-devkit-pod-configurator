#!/bin/bash

# Python/Pip Nexus Repository Validation Script
# This script validates that Python packages can be installed from Nexus repositories

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check pip configuration
check_pip_config() {
    echo -e "\n${YELLOW}Checking pip configuration:${NC}"
    
    # Check both config file and environment
    if [[ -f ~/.config/pip/pip.conf ]]; then
        echo "Config file: ~/.config/pip/pip.conf"
        # Extract URLs from pip config
        INDEX_URL=$(grep -E "^\s*index-url\s*=" ~/.config/pip/pip.conf | sed 's/.*=\s*//' | tr -d ' ')
        EXTRA_INDEX=$(grep -A2 "extra-index-url" ~/.config/pip/pip.conf | grep -v "extra-index-url" | tr -d ' ' | grep -v '^$' | head -1)
        TRUSTED_HOST=$(grep -E "^\s*trusted-host\s*=" ~/.config/pip/pip.conf | sed 's/.*=\s*//' | tr -d ' ')
        
        echo "Configured index-url: $INDEX_URL"
        if [[ -n "$EXTRA_INDEX" ]]; then
            echo "Configured extra-index-url: $EXTRA_INDEX"
        fi
        echo "Configured trusted-host: $TRUSTED_HOST"
    elif [[ -f /etc/pip.conf ]]; then
        echo "Config file: /etc/pip.conf"
        cat /etc/pip.conf
    else
        echo "No pip configuration file found"
    fi
    
    # Show pip config as reported by pip itself
    echo -e "\n${YELLOW}Pip configuration (from pip config list):${NC}"
    pip config list || echo "Unable to list pip config"
}

# Function to test PyPI repository access
test_pypi_access() {
    local repo_url="$1"
    local repo_name="$2"
    
    echo -e "\n${YELLOW}Testing $repo_name repository:${NC}"
    echo "Repository URL: $repo_url"
    
    # Extract host from URL
    local host=$(echo "$repo_url" | sed -E 's|https?://([^:/]+).*|\1|')
    
    # Test connectivity
    if curl -s --head --connect-timeout 5 "$repo_url" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Successfully connected to $repo_name${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to connect to $repo_name${NC}"
        # Try to diagnose the issue
        echo "Attempting to resolve hostname: $host"
        if nslookup "$host" >/dev/null 2>&1; then
            echo "Hostname resolves correctly"
            echo "Testing port connectivity..."
            local port=$(echo "$repo_url" | grep -oE ':[0-9]+' | tr -d ':' || echo "80")
            nc -zv "$host" "$port" 2>&1 || echo "Port $port appears to be closed or filtered"
        else
            echo "Cannot resolve hostname: $host"
        fi
        return 1
    fi
}

# Function to test package installation
test_package_install() {
    local package="$1"
    
    echo -e "\n${YELLOW}Testing installation of $package:${NC}"
    
    # Create temporary virtual environment
    local temp_venv="/tmp/test_venv_$$"
    python3 -m venv "$temp_venv"
    source "$temp_venv/bin/activate"
    
    # Upgrade pip quietly
    pip install --upgrade pip >/dev/null 2>&1
    
    # Try to install package
    if pip install "$package" --no-cache-dir --verbose 2>&1 | tee /tmp/pip_install.log | grep -q "Successfully installed"; then
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

# Function to extract URLs from pip config
extract_configured_urls() {
    local urls=()
    
    # Get index-url
    if [[ -f ~/.config/pip/pip.conf ]]; then
        local index_url=$(grep -E "^\s*index-url\s*=" ~/.config/pip/pip.conf | sed 's/.*=\s*//' | tr -d ' ')
        if [[ -n "$index_url" ]]; then
            urls+=("$index_url")
        fi
        
        # Get extra-index-urls
        local in_extra=0
        while IFS= read -r line; do
            if [[ "$line" =~ extra-index-url ]]; then
                in_extra=1
            elif [[ $in_extra -eq 1 ]]; then
                if [[ "$line" =~ ^[[:space:]]*http ]]; then
                    urls+=("$(echo "$line" | tr -d ' ')")
                elif [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
                    in_extra=0
                fi
            fi
        done < ~/.config/pip/pip.conf
    fi
    
    printf '%s\n' "${urls[@]}"
}

# Main test execution
main() {
    echo "===================================" 
    echo "Python Nexus Repository Validation"
    echo "==================================="
    echo "Python version: $(python3 --version)"
    echo "Pip version: $(pip --version)"
    
    # Check current configuration
    check_pip_config
    
    # Extract configured repository URLs
    echo -e "\n${YELLOW}Testing configured repository access:${NC}"
    
    local urls=($(extract_configured_urls))
    
    if [[ ${#urls[@]} -eq 0 ]]; then
        echo -e "${RED}No repository URLs found in pip configuration${NC}"
        echo "Please ensure pip is configured with Nexus repositories"
        exit 1
    fi
    
    # Test each configured repository
    local test_passed=0
    local test_failed=0
    
    for i in "${!urls[@]}"; do
        local url="${urls[$i]}"
        if [[ $i -eq 0 ]]; then
            local name="Primary Index"
        else
            local name="Extra Index $i"
        fi
        
        if test_pypi_access "$url" "$name"; then
            ((test_passed++))
        else
            ((test_failed++))
        fi
    done
    
    # Test actual package installation
    echo -e "\n${YELLOW}Testing package installations:${NC}"
    if test_package_install "requests"; then
        ((test_passed++))
    else
        ((test_failed++))
    fi
    
    if test_package_install "pytest"; then
        ((test_passed++))
    else
        ((test_failed++))
    fi
    
    # Summary
    echo -e "\n${GREEN}==================================="
    echo "Python Nexus Validation Complete"
    echo "===================================${NC}"
    echo "Tests passed: $test_passed"
    echo "Tests failed: $test_failed"
    
    if [[ $test_failed -gt 0 ]]; then
        echo -e "${RED}Some tests failed. Please check Nexus configuration.${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed successfully!${NC}"
    fi
}

# Run main function
main "$@"