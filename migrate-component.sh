#!/bin/bash
# Component migration helper script for separation of concerns refactor

set -euo pipefail

# Function to migrate a component with repository configuration
migrate_repository_component() {
    local component_path="$1"
    local component_name="$2"
    local format="$3"
    local config_template="$4"
    local config_output="$5"
    local mount_target="$6"
    
    echo "Migrating $component_name..."
    
    # Create directories
    mkdir -p "$component_path/ai-devkit/config-templates"
    mkdir -p "$component_path/ai-devkit/tests"
    
    # Create config.yaml
    cat > "$component_path/ai-devkit/config.yaml" <<EOF
# Configuration metadata for $component_name component
configuration:
  format: "$format"
  templates:
    - source: "config-templates/$config_template"
      output: "$config_output"
EOF
    
    # Add environment if needed
    if [[ "$format" == "go" ]]; then
        cat >> "$component_path/ai-devkit/config.yaml" <<EOF
  environment:
    - source: "env_vars.yaml"
      output: "go-env.sh"
EOF
    fi
    
    # Create volume-mounts.yaml
    local mount_name="${format}-config"
    cat > "$component_path/ai-devkit/volume-mounts.yaml" <<EOF
# Volume mount specifications for $component_name
mounts:
  - name: "$mount_name"
    source: "$config_output"
    target: "$mount_target"
    type: "file"
  - name: "${component_name}-tests"
    source: "tests/"
    target: "/home/devuser/.ai-devkit/tests/${component_name}/"
    type: "directory"
    permissions: "0755"
EOF
    
    echo "Created configuration files for $component_name"
}

# Function to create test suite for a component
create_component_tests() {
    local component_path="$1"
    local component_name="$2"
    local test_command="$3"
    local version_pattern="$4"
    
    # Create verify.sh
    cat > "$component_path/ai-devkit/tests/verify.sh" <<'EOF'
#!/bin/bash
# Verification script for COMPONENT_NAME component
set -e

COMPONENT_NAME="COMPONENT_NAME_PLACEHOLDER"
TEST_DIR="$(dirname "$0")"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Run all test scripts in order
for test in "$TEST_DIR"/test-*.sh; do
    if [[ -f "$test" ]]; then
        echo ""
        echo "Running: $(basename "$test")"
        echo "-----------------------------------------"
        if bash "$test"; then
            echo "✅ $(basename "$test"): PASSED"
        else
            echo "❌ $(basename "$test"): FAILED"
            exit 1
        fi
    fi
done

echo ""
echo "========================================="
echo "✅ All $COMPONENT_NAME tests passed!"
echo "========================================="
EOF
    
    # Replace placeholder
    sed -i "s/COMPONENT_NAME_PLACEHOLDER/$component_name/g" "$component_path/ai-devkit/tests/verify.sh"
    
    # Create version test
    cat > "$component_path/ai-devkit/tests/test-version.sh" <<EOF
#!/bin/bash
# Test $component_name version
set -e

echo "Checking $component_name version..."

if ! command -v $test_command &> /dev/null; then
    echo "❌ $test_command command not found"
    exit 1
fi

version=\$($test_command --version 2>&1 || $test_command version 2>&1 || echo "unknown")
echo "✅ $component_name version: \$version"

# Check version pattern if provided
if [[ -n "$version_pattern" ]]; then
    if [[ "\$version" =~ $version_pattern ]]; then
        echo "✅ Version matches expected pattern"
    else
        echo "⚠️  Version may not match expected pattern: $version_pattern"
    fi
fi
EOF
    
    # Make scripts executable
    chmod +x "$component_path/ai-devkit/tests"/*.sh
    
    echo "Created test suite for $component_name"
}

# Example usage
if [[ "${1:-}" == "--help" ]]; then
    echo "Usage: $0"
    echo "This script helps migrate components to the new architecture"
    exit 0
fi

echo "Component migration helper ready"
echo "Use the functions in this script to migrate components"