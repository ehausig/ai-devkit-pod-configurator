#!/bin/bash

# Test script for repository configuration system

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Repository Configuration System Test ===${NC}"
echo

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the repository configuration library
if [[ -f "${SCRIPT_DIR}/lib/repository-config.sh" ]]; then
    source "${SCRIPT_DIR}/lib/repository-config.sh"
    echo -e "${GREEN}✓${NC} Repository configuration library loaded"
else
    echo -e "${RED}✗${NC} Failed to load repository configuration library"
    exit 1
fi

echo
echo -e "${BLUE}1. Testing Component Discovery${NC}"
echo "   Finding eligible components..."

components=($(find_eligible_components))
if [[ ${#components[@]} -gt 0 ]]; then
    echo -e "   ${GREEN}✓${NC} Found ${#components[@]} eligible components:"
    for comp in "${components[@]}"; do
        IFS=':' read -r id name format file <<< "$comp"
        echo "      - $name ($format) [ID: $id]"
    done
else
    echo -e "   ${YELLOW}⚠${NC} No eligible components found"
fi

echo
echo -e "${BLUE}2. Testing Repository Configuration Functions${NC}"

# Test pip configuration generation
echo "   Testing pip configuration generation..."
test_pip_config=$(generate_pip_config "http://nexus.example.com:8081/repository/pypi-proxy" "http://pypi.org http://test.pypi.org")
if [[ -n "$test_pip_config" ]]; then
    echo -e "   ${GREEN}✓${NC} Pip configuration generated successfully"
    echo "$test_pip_config" | sed 's/^/      /'
else
    echo -e "   ${RED}✗${NC} Failed to generate pip configuration"
fi

echo
# Test npm configuration generation
echo "   Testing npm configuration generation..."
test_npm_config=$(generate_npm_config "http://nexus.example.com:8081/repository/npm-proxy/")
if [[ -n "$test_npm_config" ]]; then
    echo -e "   ${GREEN}✓${NC} NPM configuration generated successfully"
    echo "$test_npm_config" | sed 's/^/      /'
else
    echo -e "   ${RED}✗${NC} Failed to generate npm configuration"
fi

echo
# Test Maven settings generation
echo "   Testing Maven settings generation..."
test_maven_settings=$(generate_maven_settings "http://nexus.example.com:8081/repository/maven-public/" "http://repo1.maven.org/maven2")
if [[ -n "$test_maven_settings" ]]; then
    echo -e "   ${GREEN}✓${NC} Maven settings.xml generated successfully"
    echo "      (XML content generated, $(echo "$test_maven_settings" | wc -l) lines)"
else
    echo -e "   ${RED}✗${NC} Failed to generate Maven settings"
fi

echo
echo -e "${BLUE}3. Testing Component YAML Parsing${NC}"

# Test reading recommended repositories from a component
test_component="${SCRIPT_DIR}/components/languages/python-3.11.yaml"
if [[ -f "$test_component" ]]; then
    echo "   Reading Python 3.11 component configuration..."
    recommended=$(get_recommended_repositories "$test_component")
    if [[ -n "$recommended" ]]; then
        echo -e "   ${GREEN}✓${NC} Found recommended repositories:"
        while IFS= read -r repo; do
            IFS=':' read -r name url type reason <<< "$repo"
            echo "      - $name ($type): $url"
        done <<< "$recommended"
    else
        echo -e "   ${YELLOW}⚠${NC} No recommended repositories found"
    fi
else
    echo -e "   ${YELLOW}⚠${NC} Test component file not found"
fi

echo
echo -e "${BLUE}4. Testing Configuration File Handling${NC}"

# Test configuration directory
CONFIG_DIR="$HOME/.ai-devkit"
if [[ -d "$CONFIG_DIR" ]]; then
    echo -e "   ${GREEN}✓${NC} Configuration directory exists: $CONFIG_DIR"
    
    if [[ -f "$CONFIG_DIR/config.yaml" ]]; then
        echo -e "   ${GREEN}✓${NC} Main configuration file exists"
        
        # Test reading from config
        test_runtime=$(read_config "container.runtime")
        if [[ -n "$test_runtime" ]]; then
            echo -e "   ${GREEN}✓${NC} Can read configuration values (runtime: $test_runtime)"
        else
            echo -e "   ${YELLOW}⚠${NC} Configuration file exists but couldn't read values"
        fi
    else
        echo -e "   ${YELLOW}⚠${NC} Main configuration file not found"
    fi
    
    if [[ -f "$CONFIG_DIR/nexus-cache.yaml" ]]; then
        echo -e "   ${GREEN}✓${NC} Nexus cache file exists"
        
        # Test reading cached repositories
        cached_repos=$(read_nexus_cache)
        if [[ -n "$cached_repos" ]]; then
            repo_count=$(echo "$cached_repos" | wc -l)
            echo -e "   ${GREEN}✓${NC} Found $repo_count cached Nexus repositories"
        fi
    else
        echo -e "   ${YELLOW}⚠${NC} No Nexus cache file found"
    fi
else
    echo -e "   ${YELLOW}⚠${NC} Configuration directory not found"
fi

echo
echo -e "${BLUE}5. Testing Configuration Script Integration${NC}"

if [[ -f "${SCRIPT_DIR}/configure-ai-devkit.sh" ]]; then
    echo -e "   ${GREEN}✓${NC} Main configuration script exists"
    
    # Check for repository configuration functions
    if grep -q "configure_component_repositories" "${SCRIPT_DIR}/configure-ai-devkit.sh"; then
        echo -e "   ${GREEN}✓${NC} Repository configuration integrated into main script"
    else
        echo -e "   ${RED}✗${NC} Repository configuration not found in main script"
    fi
    
    if grep -q "configure_nexus_repository" "${SCRIPT_DIR}/configure-ai-devkit.sh"; then
        echo -e "   ${GREEN}✓${NC} Nexus configuration function present"
    else
        echo -e "   ${RED}✗${NC} Nexus configuration function missing"
    fi
else
    echo -e "   ${RED}✗${NC} Main configuration script not found"
fi

echo
echo -e "${BLUE}6. Testing Build Integration${NC}"

# Check if build-and-deploy.sh has the new repository support
if [[ -f "${SCRIPT_DIR}/build-and-deploy.sh" ]]; then
    if grep -q "component_repos" "${SCRIPT_DIR}/build-and-deploy.sh"; then
        echo -e "   ${GREEN}✓${NC} Build script has component repository support"
    else
        echo -e "   ${RED}✗${NC} Build script missing component repository support"
    fi
    
    if grep -q "repository-config.sh" "${SCRIPT_DIR}/build-and-deploy.sh"; then
        echo -e "   ${GREEN}✓${NC} Build script sources repository configuration library"
    else
        echo -e "   ${RED}✗${NC} Build script doesn't source repository configuration library"
    fi
else
    echo -e "   ${RED}✗${NC} Build script not found"
fi

echo
echo -e "${BLUE}7. Testing Entrypoint Integration${NC}"

if [[ -f "${SCRIPT_DIR}/lib/entrypoint-repo-setup.sh" ]]; then
    echo -e "   ${GREEN}✓${NC} Entrypoint repository setup script exists"
    
    # Check for key functions
    for func in "setup_component_repos" "setup_pip_repos" "setup_npm_repos" "setup_maven_repos"; do
        if grep -q "^${func}()" "${SCRIPT_DIR}/lib/entrypoint-repo-setup.sh"; then
            echo -e "   ${GREEN}✓${NC} Function ${func} defined"
        else
            echo -e "   ${RED}✗${NC} Function ${func} missing"
        fi
    done
else
    echo -e "   ${RED}✗${NC} Entrypoint repository setup script not found"
fi

echo
echo -e "${CYAN}=== Test Summary ===${NC}"

# Count components with repos section
components_with_repos=0
for yaml_file in ${SCRIPT_DIR}/components/**/*.yaml; do
    if grep -q "repos:" "$yaml_file" 2>/dev/null && grep -q "enabled: true" "$yaml_file" 2>/dev/null; then
        ((components_with_repos++))
    fi
done

echo -e "   • Components with repository support: ${BOLD}${components_with_repos}${NC}"
echo -e "   • Configuration directory: ${BOLD}${CONFIG_DIR}${NC}"
echo -e "   • Repository formats supported: ${BOLD}pypi, npm, go, maven2, cargo, rubygems${NC}"

echo
echo -e "${GREEN}Repository configuration system test complete!${NC}"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Run ${BOLD}./configure-ai-devkit.sh${NC} to configure both container runtime and repositories"
echo "  2. Run ${BOLD}./build-and-deploy.sh${NC} to build components with repository support"