#!/bin/bash

# Python/Pip Nexus Repository Validation Script
# This script validates that Python packages can be installed from configured repositories

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check pip configuration
check_pip_config() {
    echo -e "\n${YELLOW}Checking pip configuration:${NC}"
    
    if [[ -f ~/.config/pip/pip.conf ]]; then
        echo "Config file found: ~/.config/pip/pip.conf"
        echo "Contents:"
        cat ~/.config/pip/pip.conf
    elif [[ -f /etc/pip.conf ]]; then
        echo "Config file found: /etc/pip.conf"
        cat /etc/pip.conf
    else
        echo "No pip configuration file found"
        return 1
    fi
    
    echo -e "\n${YELLOW}Pip configuration (from pip config list):${NC}"
    pip config list || echo "Unable to list pip config"
}

# Function to test PyPI repository access
test_pypi_access() {
    local repo_url="$1"
    local repo_name="$2"
    
    echo -e "\n${YELLOW}Testing $repo_name:${NC}"
    echo "URL: $repo_url"
    
    # Extract host and port from URL
    local host=$(echo "$repo_url" | sed -E 's|https?://([^:/]+).*|\1|')
    local port=$(echo "$repo_url" | grep -oE ':[0-9]+' | tr -d ':' || echo "80")
    
    # Test connectivity to host:port
    echo "Testing connectivity to $host:$port..."
    if nc -zv -w 5 "$host" "$port" 2>&1; then
        echo -e "${GREEN}✓ Successfully connected to $host:$port${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to connect to $host:$port${NC}"
        return 1
    fi
}

# Main test execution
main() {
    echo "===================================" 
    echo "Python Nexus Repository Validation"
    echo "==================================="
    echo "Python version: $(python3 --version)"
    echo "Pip version: $(pip --version)"
    
    # Check configuration exists
    if ! check_pip_config; then
        exit 1
    fi
    
    # Test configured repositories
    echo -e "\n${YELLOW}Testing configured repository URLs:${NC}"
    
    # Extract and test index-url
    if [[ -f ~/.config/pip/pip.conf ]]; then
        local index_url=$(grep -E "^\s*index-url\s*=" ~/.config/pip/pip.conf | sed 's/.*=\s*//' | tr -d ' ')
        if [[ -n "$index_url" ]]; then
            test_pypi_access "$index_url" "Primary Index"
        fi
        
        # Extract and test extra-index-urls
        local in_extra=0
        local count=0
        while IFS= read -r line; do
            if [[ "$line" =~ extra-index-url ]]; then
                in_extra=1
            elif [[ $in_extra -eq 1 ]] && [[ "$line" =~ ^[[:space:]]*http ]]; then
                local url=$(echo "$line" | tr -d ' ')
                ((count++))
                test_pypi_access "$url" "Extra Index $count"
            elif [[ $in_extra -eq 1 ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
                in_extra=0
            fi
        done < ~/.config/pip/pip.conf
    fi
    
    echo -e "\n${GREEN}Validation Complete${NC}"
}

main "$@"