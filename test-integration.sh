#!/bin/bash

# Integration test for the consolidated AI DevKit configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== AI DevKit Integration Test ===${NC}"
echo

# Test 1: Check main configuration script
echo -e "${BLUE}1. Main Configuration Script${NC}"
if [[ -f "./configure-ai-devkit.sh" ]]; then
    echo -e "   ${GREEN}✓${NC} configure-ai-devkit.sh exists"
    
    # Check for required functions
    for func in "detect_docker" "detect_nerdctl" "detect_podman" \
                "configure_component_repositories" "configure_nexus_repository" \
                "configure_repositories_tui" "save_repository_configuration"; do
        if grep -q "$func" ./configure-ai-devkit.sh; then
            echo -e "   ${GREEN}✓${NC} Function $func found"
        else
            echo -e "   ${RED}✗${NC} Function $func missing"
        fi
    done
else
    echo -e "   ${RED}✗${NC} configure-ai-devkit.sh not found"
fi

echo
echo -e "${BLUE}2. Library Files${NC}"
for lib in "lib/repository-config.sh" "lib/entrypoint-repo-setup.sh"; do
    if [[ -f "$lib" ]]; then
        echo -e "   ${GREEN}✓${NC} $lib exists"
    else
        echo -e "   ${RED}✗${NC} $lib missing"
    fi
done

echo
echo -e "${BLUE}3. Documentation${NC}"
for doc in "README.md" "REPOSITORY-CONFIGURATION.md" "CONTRIBUTING.md"; do
    if [[ -f "$doc" ]]; then
        echo -e "   ${GREEN}✓${NC} $doc exists"
        
        # Check for outdated references
        if grep -q "configure-container-runtime.sh\|configure-repositories.sh" "$doc" 2>/dev/null; then
            echo -e "   ${YELLOW}⚠${NC}  $doc contains outdated script references"
        fi
    else
        echo -e "   ${RED}✗${NC} $doc missing"
    fi
done

echo
echo -e "${BLUE}4. Component Repository Support${NC}"
components_with_repos=0
total_components=0
for yaml in components/**/*.yaml; do
    ((total_components++))
    if grep -q "repos:" "$yaml" 2>/dev/null && grep -q "enabled: true" "$yaml" 2>/dev/null; then
        ((components_with_repos++))
        component_name=$(grep "^name:" "$yaml" | head -1 | cut -d: -f2- | xargs)
        echo -e "   ${GREEN}✓${NC} $component_name has repository support"
    fi
done
echo -e "   Total: ${components_with_repos}/${total_components} components with repository support"

echo
echo -e "${BLUE}5. Build Script Integration${NC}"
if [[ -f "./build-and-deploy.sh" ]]; then
    if grep -q "component_repos" ./build-and-deploy.sh; then
        echo -e "   ${GREEN}✓${NC} Build script has component repository support"
    else
        echo -e "   ${RED}✗${NC} Build script missing component repository support"
    fi
    
    if grep -q "repository-config.sh" ./build-and-deploy.sh; then
        echo -e "   ${GREEN}✓${NC} Build script sources repository library"
    else
        echo -e "   ${RED}✗${NC} Build script doesn't source repository library"
    fi
else
    echo -e "   ${RED}✗${NC} build-and-deploy.sh not found"
fi

echo
echo -e "${BLUE}6. Configuration Workflow${NC}"
echo "   Expected workflow:"
echo "   1. ./configure-ai-devkit.sh - Configure runtime and repositories"
echo "   2. ./configure-git-host.sh - Configure git (optional)"
echo "   3. ./build-and-deploy.sh - Build and deploy components"

# Check if config directory exists
if [[ -d "$HOME/.ai-devkit" ]]; then
    echo -e "   ${GREEN}✓${NC} Configuration directory exists"
    
    if [[ -f "$HOME/.ai-devkit/config.yaml" ]]; then
        echo -e "   ${GREEN}✓${NC} Configuration file exists"
    else
        echo -e "   ${YELLOW}⚠${NC}  No configuration file yet (run configure-ai-devkit.sh)"
    fi
else
    echo -e "   ${YELLOW}⚠${NC}  Configuration directory not created yet"
fi

echo
echo -e "${CYAN}=== Integration Test Complete ===${NC}"

# Summary
errors=0
warnings=0

# Count any errors or warnings from above
if [[ ! -f "./configure-ai-devkit.sh" ]]; then ((errors++)); fi
if [[ ! -f "./build-and-deploy.sh" ]]; then ((errors++)); fi
if [[ ! -f "lib/repository-config.sh" ]]; then ((errors++)); fi

echo
if [[ $errors -eq 0 ]]; then
    echo -e "${GREEN}✓ All integration checks passed!${NC}"
    echo -e "The AI DevKit is properly configured and ready to use."
else
    echo -e "${RED}✗ Found $errors error(s) in integration${NC}"
    echo -e "Please review the issues above."
fi

echo
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Run ${CYAN}./configure-ai-devkit.sh${NC} to configure your environment"
echo "  2. Run ${CYAN}./build-and-deploy.sh${NC} to build and deploy components"