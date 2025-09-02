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
    
    # Mount tests to a shared directory since all test files are now in flat structure
    # Each component's tests are prefixed with component ID
    cat <<EOF
- name: "component-tests"
  source: "tests/"
  target: "/home/devuser/.ai-devkit/tests/"
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

# Track which components we've tested
declare -A tested_components

# Run all verify.sh scripts (now prefixed with component ID)
for verify_script in /home/devuser/.ai-devkit/tests/*-verify.sh; do
    if [[ -f "$verify_script" ]]; then
        # Extract component ID from filename (e.g., python-3-11-verify.sh -> python-3-11)
        basename=$(basename "$verify_script")
        component_id="${basename%-verify.sh}"
        
        echo ""
        echo "Testing $component_id..."
        echo "-----------------------------------------"
        
        if bash "$verify_script"; then
            echo "✅ $component_id: PASSED"
            PASSED=$((PASSED + 1))
        else
            echo "❌ $component_id: FAILED"
            FAILED=$((FAILED + 1))
        fi
        
        tested_components["$component_id"]=1
    fi
done

# Check for component test files without verify.sh
for test_file in /home/devuser/.ai-devkit/tests/*-test-*.sh; do
    if [[ -f "$test_file" ]]; then
        # Extract component ID from filename
        basename=$(basename "$test_file")
        component_id="${basename%%-test-*}"
        
        # If we haven't tested this component yet, it's missing verify.sh
        if [[ -z "${tested_components[$component_id]}" ]]; then
            echo "⚠️  $component_id: Has test files but no verify.sh (SKIPPED)"
            SKIPPED=$((SKIPPED + 1))
            tested_components["$component_id"]=1
        fi
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
    local component_id="$2"  # Using component ID instead of display name
    local staging_dir="$3"
    
    local test_dir="$component_dir/ai-devkit/tests"
    if [[ ! -d "$test_dir" ]]; then
        echo "No tests found for $component_id" >&2
        return 0
    fi
    
    # Stage test files directly to tests/ directory (not in subdirectory)
    # This matches where ConfigMap generation expects them
    local test_staging="$staging_dir/tests"
    mkdir -p "$test_staging"
    
    # Copy all test files with component prefix to avoid conflicts
    local sanitized_id=$(echo "$component_id" | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    for file in "$test_dir"/*; do
        if [[ -f "$file" ]]; then
            local basename=$(basename "$file")
            # Prefix with component ID to avoid conflicts between components
            cp "$file" "$test_staging/${sanitized_id}-${basename}" 2>/dev/null || true
        fi
    done
    
    # Ensure scripts are executable
    find "$test_staging" -name "*.sh" -type f -exec chmod +x {} \;
    
    echo "Staged tests for $component_id to $test_staging"
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