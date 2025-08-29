#!/bin/bash
# Batch migration script for components without repository configurations

set -euo pipefail

# Function to create minimal ai-devkit structure for components without repos
create_minimal_structure() {
    local component_path="$1"
    local component_name="$2"
    local test_command="$3"
    
    echo "Creating minimal structure for $component_name..."
    
    # Create directories
    mkdir -p "$component_path/ai-devkit/tests"
    
    # Create minimal config.yaml (no repos, just tests)
    cat > "$component_path/ai-devkit/config.yaml" <<EOF
# Configuration metadata for $component_name component
# This component has no repository configuration
configuration: {}
EOF
    
    # Create volume-mounts.yaml for tests only
    cat > "$component_path/ai-devkit/volume-mounts.yaml" <<EOF
# Volume mount specifications for $component_name
mounts:
  - name: "${component_name}-tests"
    source: "tests/"
    target: "/home/devuser/.ai-devkit/tests/${component_name}/"
    type: "directory"
    permissions: "0755"
EOF
    
    # Create basic verify.sh test
    cat > "$component_path/ai-devkit/tests/verify.sh" <<EOF
#!/bin/bash
# Verification script for $component_name component
set -e

COMPONENT_NAME="$component_name"

echo "========================================="
echo "Verifying \$COMPONENT_NAME installation"
echo "========================================="

# Check if component is installed
if ! command -v $test_command &> /dev/null; then
    echo "❌ $test_command command not found"
    exit 1
fi

# Get version
version=\$($test_command --version 2>&1 || $test_command version 2>&1 || echo "version check failed")
echo "✅ \$COMPONENT_NAME: \$version"

echo "✅ \$COMPONENT_NAME verification passed!"
EOF
    
    chmod +x "$component_path/ai-devkit/tests/verify.sh"
    echo "Created minimal structure for $component_name"
}

# Migrate components without repository configurations
create_minimal_structure "components/languages/java-11-openjdk" "java-11-openjdk" "java"
create_minimal_structure "components/languages/java-17-openjdk" "java-17-openjdk" "java"
create_minimal_structure "components/languages/java-21-openjdk" "java-21-openjdk" "java"
create_minimal_structure "components/languages/java-11-adoptium" "java-11-adoptium" "java"
create_minimal_structure "components/languages/java-17-adoptium" "java-17-adoptium" "java"
create_minimal_structure "components/languages/java-21-adoptium" "java-21-adoptium" "java"
create_minimal_structure "components/languages/kotlin" "kotlin" "kotlinc"
create_minimal_structure "components/languages/nodejs-22" "nodejs-22" "node"
create_minimal_structure "components/languages/python-default" "python-default" "python3"
create_minimal_structure "components/languages/python-miniconda" "python-miniconda" "conda"
create_minimal_structure "components/languages/ruby-3.3" "ruby-3.3" "ruby"
create_minimal_structure "components/languages/ruby-system" "ruby-system" "ruby"
create_minimal_structure "components/languages/rust-nightly" "rust-nightly" "rustc"
create_minimal_structure "components/languages/scala-2.13" "scala-2.13" "scala"
create_minimal_structure "components/languages/scala-3" "scala-3" "scala"
create_minimal_structure "components/languages/go-1.21" "go-1.21" "go"

echo "Batch migration complete!"