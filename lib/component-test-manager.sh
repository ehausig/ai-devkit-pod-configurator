#!/bin/bash
# Component Test Manager
# Handles test injection and orchestration for components

set -euo pipefail

# Collect component tests for injection
collect_component_tests() {
    local component_dir="$1"
    local component_name="$2"
    local test_dir="$component_dir/ai-devkit/tests"
    
    if [[ ! -d "$test_dir" ]]; then
        return 0  # No tests defined, not an error
    fi
    
    # Return test directory info for mounting
    echo "$test_dir"
}

# Generate test mount specifications
generate_test_mounts() {
    local component_dir="$1"
    local component_name="$2"
    
    local test_dir="$component_dir/ai-devkit/tests"
    if [[ ! -d "$test_dir" ]]; then
        return 0
    fi
    
    # Generate mount specification for test directory
    cat <<EOF
- name: "${component_name}-tests"
  source: "tests/"
  target: "/home/devuser/.ai-devkit/tests/${component_name}/"
  type: "directory"
  permissions: "0755"
  component: "$component_name"
EOF
}

# Create global test orchestrator
create_test_orchestrator() {
    local output_dir="$1"
    
    cat > "$output_dir/run-all.sh" <<'EOF'
#!/bin/bash
# AI DevKit Component Test Orchestrator
# Runs all component verification tests

set -e

echo "========================================="
echo "AI DevKit Component Verification"
echo "========================================="

FAILED=0
PASSED=0
SKIPPED=0

# Find all component test directories
for component_test_dir in /home/devuser/.ai-devkit/tests/*/; do
    if [[ -d "$component_test_dir" ]] && [[ -f "$component_test_dir/verify.sh" ]]; then
        component=$(basename "$component_test_dir")
        echo ""
        echo "Testing $component..."
        echo "-----------------------------------------"
        
        if bash "$component_test_dir/verify.sh"; then
            echo "✅ $component: PASSED"
            PASSED=$((PASSED + 1))
        else
            echo "❌ $component: FAILED"
            FAILED=$((FAILED + 1))
        fi
    fi
done

# Check for components without tests
for component_test_dir in /home/devuser/.ai-devkit/tests/*/; do
    if [[ -d "$component_test_dir" ]] && [[ ! -f "$component_test_dir/verify.sh" ]]; then
        component=$(basename "$component_test_dir")
        echo "⚠️  $component: No verify.sh found (SKIPPED)"
        SKIPPED=$((SKIPPED + 1))
    fi
done

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "✅ Passed:  $PASSED"
echo "❌ Failed:  $FAILED"
echo "⚠️  Skipped: $SKIPPED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo "All component tests passed!"
    exit 0
else
    echo "$FAILED component(s) failed verification"
    exit 1
fi
EOF
    
    chmod +x "$output_dir/run-all.sh"
    echo "Created test orchestrator: $output_dir/run-all.sh"
}

# Copy component tests to staging directory
stage_component_tests() {
    local component_dir="$1"
    local component_name="$2"
    local staging_dir="$3"
    
    local test_dir="$component_dir/ai-devkit/tests"
    if [[ ! -d "$test_dir" ]]; then
        echo "No tests found for $component_name" >&2
        return 0
    fi
    
    # Create staging directory for tests
    local test_staging="$staging_dir/tests/$component_name"
    mkdir -p "$test_staging"
    
    # Copy all test files
    cp -r "$test_dir"/* "$test_staging/" 2>/dev/null || true
    
    # Ensure scripts are executable
    find "$test_staging" -name "*.sh" -type f -exec chmod +x {} \;
    
    echo "Staged tests for $component_name"
    return 0
}

# Validate component tests
validate_component_tests() {
    local component_dir="$1"
    local component_name="$2"
    
    local test_dir="$component_dir/ai-devkit/tests"
    if [[ ! -d "$test_dir" ]]; then
        echo "WARNING: No tests defined for component $component_name" >&2
        return 1
    fi
    
    # Check for required verify.sh
    if [[ ! -f "$test_dir/verify.sh" ]]; then
        echo "WARNING: Missing verify.sh for component $component_name" >&2
        return 1
    fi
    
    # Check that verify.sh is executable
    if [[ ! -x "$test_dir/verify.sh" ]]; then
        chmod +x "$test_dir/verify.sh"
        echo "Fixed: Made verify.sh executable for $component_name" >&2
    fi
    
    return 0
}

# Export functions
export -f collect_component_tests
export -f generate_test_mounts
export -f create_test_orchestrator
export -f stage_component_tests
export -f validate_component_tests