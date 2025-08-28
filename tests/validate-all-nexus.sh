#!/bin/bash

# Main test runner to validate all Nexus repository configurations
# Run this inside the deployed container to verify all component Nexus access

set -e

echo "============================================="
echo "AI DevKit Nexus Repository Validation Suite"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Function to print section header
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to check if a component is installed
check_component() {
    local component="$1"
    local check_cmd="$2"
    
    if command -v $check_cmd &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to run a test script
run_test() {
    local test_name="$1"
    local test_script="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ ! -f "$test_script" ]]; then
        echo -e "${YELLOW}⚠ Test script not found: $test_script${NC}"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        return 1
    fi
    
    echo -e "${YELLOW}Running: $test_name${NC}"
    
    if bash "$test_script"; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Function to check Nexus connectivity
check_nexus_connectivity() {
    print_header "Checking Nexus Server Connectivity"
    
    # Check if Nexus hostname resolves
    if getent hosts nexus &> /dev/null; then
        echo -e "${GREEN}✓ Nexus hostname resolves${NC}"
        getent hosts nexus
    else
        echo -e "${RED}✗ Nexus hostname does not resolve${NC}"
        echo "Checking /etc/hosts..."
        grep nexus /etc/hosts || echo "No nexus entry in /etc/hosts"
        return 1
    fi
    
    # Check common Nexus ports
    local ports=(8081 8082 8083 8084 8085 8090 8091)
    echo -e "\n${YELLOW}Checking Nexus ports:${NC}"
    
    for port in "${ports[@]}"; do
        if nc -z nexus $port 2>/dev/null; then
            echo -e "${GREEN}✓ Port $port is open${NC}"
        else
            echo -e "${YELLOW}⚠ Port $port is not accessible${NC}"
        fi
    done
    
    # Try to fetch Nexus status
    if curl -s -o /dev/null -w "%{http_code}" http://nexus:8081/service/rest/v1/status 2>/dev/null | grep -q "200"; then
        echo -e "${GREEN}✓ Nexus REST API is accessible${NC}"
    else
        echo -e "${YELLOW}⚠ Nexus REST API not accessible (may require authentication)${NC}"
    fi
}

# Function to display environment info
show_environment_info() {
    print_header "Environment Information"
    
    echo "Container OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Hostname: $(hostname)"
    echo "IP Address: $(hostname -I | awk '{print $1}')"
    
    echo -e "\n${YELLOW}Installed Components:${NC}"
    
    if check_component "Python" "python3"; then
        echo -e "${GREEN}✓ Python $(python3 --version 2>&1)${NC}"
    else
        echo -e "${RED}✗ Python not found${NC}"
    fi
    
    if check_component "Node.js" "node"; then
        echo -e "${GREEN}✓ Node.js $(node --version)${NC}"
    else
        echo -e "${RED}✗ Node.js not found${NC}"
    fi
    
    if check_component "npm" "npm"; then
        echo -e "${GREEN}✓ npm $(npm --version)${NC}"
    else
        echo -e "${RED}✗ npm not found${NC}"
    fi
    
    if check_component "pip" "pip"; then
        echo -e "${GREEN}✓ pip $(pip --version | awk '{print $2}')${NC}"
    else
        echo -e "${RED}✗ pip not found${NC}"
    fi
}

# Function to run all validation tests
run_all_tests() {
    print_header "Running Component Validation Tests"
    
    # Python Nexus validation
    if check_component "Python" "python3"; then
        run_test "Python Nexus Validation" "$SCRIPT_DIR/validate-python-nexus.sh"
    else
        echo -e "${YELLOW}⚠ Skipping Python tests - Python not installed${NC}"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    fi
    
    echo ""
    
    # Node.js Nexus validation
    if check_component "Node.js" "node"; then
        run_test "Node.js Nexus Validation" "$SCRIPT_DIR/validate-nodejs-nexus.sh"
    else
        echo -e "${YELLOW}⚠ Skipping Node.js tests - Node.js not installed${NC}"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    fi
}

# Function to display summary
display_summary() {
    print_header "Validation Summary"
    
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed:      ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:      ${RED}$FAILED_TESTS${NC}"
    echo -e "Skipped:     ${YELLOW}$SKIPPED_TESTS${NC}"
    
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 && $PASSED_TESTS -gt 0 ]]; then
        echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   All tests passed successfully!   ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
        return 0
    elif [[ $PASSED_TESTS -eq 0 && $FAILED_TESTS -eq 0 ]]; then
        echo -e "${YELLOW}╔════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║     No tests were executed         ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════╝${NC}"
        return 1
    else
        echo -e "${RED}╔════════════════════════════════════╗${NC}"
        echo -e "${RED}║     Some tests failed!             ║${NC}"
        echo -e "${RED}╚════════════════════════════════════╝${NC}"
        return 1
    fi
}

# Function to generate detailed report
generate_report() {
    local report_file="/tmp/nexus-validation-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "AI DevKit Nexus Repository Validation Report"
        echo "============================================="
        echo "Generated: $(date)"
        echo ""
        echo "Environment:"
        echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
        echo "  Hostname: $(hostname)"
        echo ""
        echo "Test Results:"
        echo "  Total: $TOTAL_TESTS"
        echo "  Passed: $PASSED_TESTS"
        echo "  Failed: $FAILED_TESTS"
        echo "  Skipped: $SKIPPED_TESTS"
        echo ""
        echo "Configuration Files:"
        echo ""
        echo "NPM Configuration:"
        npm config list 2>/dev/null || echo "  Not available"
        echo ""
        echo "Pip Configuration:"
        pip config list 2>/dev/null || echo "  Not available"
        echo ""
        echo "Network Configuration:"
        echo "  /etc/hosts entries:"
        grep -E "nexus|repository" /etc/hosts 2>/dev/null || echo "    None found"
        echo ""
        echo "Environment Variables:"
        env | grep -E "NPM_|PIP_|NEXUS_" || echo "  None found"
    } > "$report_file"
    
    echo -e "\n${BLUE}Detailed report saved to: $report_file${NC}"
}

# Main execution
main() {
    echo "Starting Nexus repository validation..."
    echo "Date: $(date)"
    echo ""
    
    # Show environment information
    show_environment_info
    
    # Check Nexus connectivity
    check_nexus_connectivity
    
    # Run all validation tests
    run_all_tests
    
    # Display summary
    display_summary
    exit_code=$?
    
    # Generate detailed report
    generate_report
    
    exit $exit_code
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --python       Run only Python validation"
        echo "  --nodejs       Run only Node.js validation"
        echo "  --quick        Skip connectivity checks"
        echo ""
        echo "This script validates Nexus repository configurations for all components."
        exit 0
        ;;
    --python)
        if [[ -f "$SCRIPT_DIR/validate-python-nexus.sh" ]]; then
            exec bash "$SCRIPT_DIR/validate-python-nexus.sh"
        else
            echo "Python validation script not found"
            exit 1
        fi
        ;;
    --nodejs)
        if [[ -f "$SCRIPT_DIR/validate-nodejs-nexus.sh" ]]; then
            exec bash "$SCRIPT_DIR/validate-nodejs-nexus.sh"
        else
            echo "Node.js validation script not found"
            exit 1
        fi
        ;;
    --quick)
        run_all_tests
        display_summary
        ;;
    *)
        main
        ;;
esac