#!/bin/bash
# Run all tests for the event-driven persona system

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Change to tests directory
cd "$(dirname "$0")"

# Ensure scripts are in PATH
export PATH="../scripts/event-sourcing:../scripts/personas:../scripts/common:$PATH"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Event-Driven Persona System Tests${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Track overall results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Run each test suite
for test_file in test-*.sh; do
  if [ -f "$test_file" ] && [ "$test_file" != "test-framework.sh" ]; then
    ((TOTAL_SUITES++))

    echo -e "${YELLOW}Running $test_file...${NC}"

    if bash "$test_file"; then
      ((PASSED_SUITES++))
      echo -e "${GREEN}✓ $test_file passed${NC}"
    else
      ((FAILED_SUITES++))
      echo -e "${RED}✗ $test_file failed${NC}"
    fi

    echo ""
  fi
done

# Summary
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo "Test suites run:    $TOTAL_SUITES"
echo -e "Test suites passed: ${GREEN}$PASSED_SUITES${NC}"
echo -e "Test suites failed: ${RED}$FAILED_SUITES${NC}"

if [ $FAILED_SUITES -eq 0 ]; then
  echo -e "\n${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "\n${RED}Some tests failed!${NC}"
  exit 1
fi
