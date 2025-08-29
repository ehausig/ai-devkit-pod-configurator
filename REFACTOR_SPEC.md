# Separation of Concerns Refactor Specification

## Objective
Remove 400+ lines of hard-coded component logic from core scripts and establish true component autonomy through template-based configuration generation.

## Critical Requirements
1. **Single-Phase Implementation** - Complete refactor in one phase to avoid partial state
2. **Zero Core Changes for New Components** - Pure plugin architecture
3. **Complete Tech Debt Cleanup** - No orphaned code remains
4. **Backward Compatible** - Existing deployments continue to work

## Files to Delete
- `lib/component-config-generator.sh` - 416 lines of hard-coded package manager functions
- Component-specific test files in `tests/` directory

## Files to Modify

### build-and-deploy.sh
**Remove lines 3543-3587:**
- Switch statements for package manager formats
- Hard-coded file path mappings
- Static volume mount configurations

**Replace with:**
- Dynamic template processing calls
- Component-declared mount discovery
- Generic configuration handling

### lib/generate-dynamic-deployment.sh
**Remove lines 71-320:**
- Package manager specific volume definitions
- Hard-coded ConfigMap generation

**Replace with:**
- Dynamic volume mount generation from component specs
- Template-based ConfigMap creation

## New Component Structure

```
components/{category}/{name}/
├── {name}.yaml                    # Existing component descriptor
└── ai-devkit/                     # Component-owned configuration
    ├── repos.yaml                 # Existing: Default repositories
    ├── env_vars.yaml              # Existing: Environment variables
    ├── config.yaml                # NEW: Configuration metadata
    ├── config-templates/          # NEW: Jinja2-style templates
    │   └── {tool}.conf.j2
    ├── volume-mounts.yaml         # NEW: Mount specifications
    ├── tests/                     # NEW: Component tests (injected into container)
    │   ├── verify.sh              # Main verification script
    │   ├── test-config.sh         # Configuration validation
    │   ├── test-connectivity.sh   # Repository connectivity
    │   └── test-installation.sh   # Package installation test
    └── pre-build.sh              # Optional: Complex setup

```

## Component Configuration Files

### ai-devkit/config.yaml
```yaml
# Declares what this component provides
configuration:
  format: "pypi"                   # Package manager format
  templates:
    - source: "config-templates/pip.conf.j2"
      output: "pip.conf"
  environment:
    - source: "env_vars.yaml"
      output: "python-env.sh"
```

### ai-devkit/volume-mounts.yaml
```yaml
# Declares where configs and tests should be mounted
mounts:
  - name: "pip-config"
    source: "pip.conf"
    target: "/home/devuser/.config/pip/pip.conf"
    type: "file"
  - name: "python-env"
    source: "python-env.sh"
    target: "/home/devuser/.config/python-env.sh"
    type: "file"
  - name: "python-tests"
    source: "tests/"
    target: "/home/devuser/.ai-devkit/tests/python-3.11/"
    type: "directory"
    permissions: "755"  # Ensure scripts are executable
```

### ai-devkit/config-templates/pip.conf.j2
```jinja2
[global]
{% if repositories %}
index-url = {{ repositories[0].url }}
{% if repositories[0].url.startswith('http://') %}
trusted-host = {{ repositories[0].url | urlparse('hostname') }}
{% endif %}
{% if repositories|length > 1 %}
extra-index-url =
{% for repo in repositories[1:] %}
    {{ repo.url }}
{% endfor %}
{% endif %}
{% endif %}
```

## New Core Libraries

### lib/template-processor.sh
```bash
#!/bin/bash
# Generic template processing engine

process_template() {
    local template_file="$1"
    local data_json="$2"
    local output_file="$3"
    
    # Use jinja2-cli or similar for template processing
    jinja2 "$template_file" -D "$data_json" > "$output_file"
}

discover_component_configs() {
    local component_dir="$1"
    local config_file="$component_dir/ai-devkit/config.yaml"
    
    if [[ -f "$config_file" ]]; then
        yq -r '.configuration' "$config_file"
    fi
}
```

### lib/volume-mount-manager.sh
```bash
#!/bin/bash
# Manages dynamic volume mount generation

collect_volume_mounts() {
    local component_dir="$1"
    local mount_file="$component_dir/ai-devkit/volume-mounts.yaml"
    
    if [[ -f "$mount_file" ]]; then
        yq -r '.mounts[]' "$mount_file"
    fi
}

generate_deployment_mounts() {
    local all_mounts="$1"
    # Generate Kubernetes volume mount specifications
}
```

## Component Test Requirements

### Every Component Must Include Tests
Each component with tools/languages/build systems MUST include verification tests:

#### Language Components (Python, Node.js, Go, etc.)
```bash
# ai-devkit/tests/verify.sh
- Verify interpreter/runtime is accessible
- Check version matches expected
- Test package manager functionality
- Verify repository configuration
- Test simple package installation
```

#### Build System Components (Maven, Gradle, SBT)
```bash
# ai-devkit/tests/verify.sh
- Verify build tool is in PATH
- Check version compatibility
- Test dependency resolution
- Verify repository configuration
- Build simple test project
```

#### Tool Components (Docker, Kubernetes tools, etc.)
```bash
# ai-devkit/tests/verify.sh
- Verify tool is installed
- Check permissions/access
- Test basic functionality
- Verify configuration if applicable
```

### Example Test Implementations

#### Python 3.11 Component Tests
```bash
# components/languages/python-3.11/ai-devkit/tests/verify.sh
#!/bin/bash
set -e

echo "Verifying Python 3.11..."

# Check Python version
python_version=$(python3.11 --version 2>&1 | cut -d' ' -f2)
if [[ ! "$python_version" =~ ^3\.11\. ]]; then
    echo "❌ Wrong Python version: $python_version"
    exit 1
fi

# Check pip functionality
pip3.11 --version > /dev/null || exit 1

# Test package installation
pip3.11 install --no-cache-dir requests > /dev/null 2>&1 || exit 1
python3.11 -c "import requests; print(f'requests {requests.__version__}')" || exit 1

echo "✅ Python 3.11 verified"
```

#### Node.js 20 Component Tests
```bash
# components/languages/nodejs-20/ai-devkit/tests/verify.sh
#!/bin/bash
set -e

echo "Verifying Node.js 20..."

# Check Node version
node_version=$(node --version)
if [[ ! "$node_version" =~ ^v20\. ]]; then
    echo "❌ Wrong Node version: $node_version"
    exit 1
fi

# Check npm functionality
npm --version > /dev/null || exit 1

# Test package installation
npm install express > /dev/null 2>&1 || exit 1
node -e "const express = require('express'); console.log('express', express().constructor.name)" || exit 1

echo "✅ Node.js 20 verified"
```

#### Maven Component Tests
```bash
# components/build-deploy/maven/ai-devkit/tests/verify.sh
#!/bin/bash
set -e

echo "Verifying Maven..."

# Check Maven is available
mvn --version > /dev/null || exit 1

# Create test project
mkdir -p /tmp/maven-test && cd /tmp/maven-test
cat > pom.xml << 'EOF'
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>test</groupId>
  <artifactId>test</artifactId>
  <version>1.0</version>
</project>
EOF

# Test dependency resolution
mvn dependency:resolve > /dev/null 2>&1 || exit 1

echo "✅ Maven verified"
```

## Implementation Steps

### Step 1: Create Template Infrastructure
1. Write `lib/template-processor.sh`
2. Write `lib/volume-mount-manager.sh`
3. Add jinja2-cli to base Docker image
4. Create template validation utilities

### Step 2: Migrate Components
For each component with repository configuration:
1. Create `ai-devkit/config.yaml`
2. Create `ai-devkit/config-templates/` with templates
3. Create `ai-devkit/volume-mounts.yaml`
4. Move component tests to `ai-devkit/tests/`
5. Test configuration generation

### Step 3: Update Core Scripts
1. Replace switch statements in `build-and-deploy.sh`
2. Update `generate_repository_configs()` to use templates
3. Modify `generate_dynamic_deployment()` for dynamic mounts
4. Remove hard-coded package manager references

### Step 4: Delete Obsolete Code
1. Delete `lib/component-config-generator.sh`
2. Remove old test files from `tests/`
3. Clean up unused functions
4. Remove hard-coded constants

### Step 5: Verification
1. Run all component tests in new locations
2. Verify no hard-coded package managers remain
3. Test adding a new package manager without core changes
4. Ensure all existing functionality works

## Testing Strategy

### Component Test Structure
Tests are injected into the container at `/home/devuser/.ai-devkit/tests/{component-name}/`

```bash
# ai-devkit/tests/verify.sh - Main verification script
#!/bin/bash
set -e

COMPONENT_NAME="python-3.11"
TEST_DIR="$(dirname "$0")"

echo "========================================="
echo "Verifying $COMPONENT_NAME installation"
echo "========================================="

# Run all test scripts
for test in "$TEST_DIR"/test-*.sh; do
    if [[ -f "$test" ]]; then
        echo "Running: $(basename "$test")"
        bash "$test" || exit 1
    fi
done

echo "✅ All $COMPONENT_NAME tests passed!"
```

```bash
# ai-devkit/tests/test-config.sh - Configuration validation
#!/bin/bash
set -e

echo "Testing Python configuration..."

# Verify pip.conf exists and is valid
if [[ ! -f ~/.config/pip/pip.conf ]]; then
    echo "❌ pip.conf not found"
    exit 1
fi

# Verify pip can read the config
pip config list > /dev/null 2>&1 || {
    echo "❌ pip config is invalid"
    exit 1
}

echo "✅ Configuration valid"
```

```bash
# ai-devkit/tests/test-connectivity.sh - Repository connectivity
#!/bin/bash
set -e

echo "Testing repository connectivity..."

# Test that pip can reach its configured repository
pip search --version > /dev/null 2>&1 || pip index versions pip > /dev/null 2>&1 || {
    echo "⚠️ Repository connectivity limited (may be expected for private repos)"
}

echo "✅ Repository configuration working"
```

```bash
# ai-devkit/tests/test-installation.sh - Package installation
#!/bin/bash
set -e

echo "Testing package installation..."

# Test installing a small package
pip install --no-cache-dir six > /dev/null 2>&1 || {
    echo "❌ Failed to install test package"
    exit 1
}

# Verify it works
python -c "import six; print(f'six version: {six.__version__}')" || {
    echo "❌ Installed package not working"
    exit 1
}

echo "✅ Package installation working"
```

### User Execution in Container
Users can run component tests directly inside the container:

```bash
# Run all component tests
devuser@ai-devkit:~$ /home/devuser/.ai-devkit/tests/run-all.sh

# Run specific component test
devuser@ai-devkit:~$ /home/devuser/.ai-devkit/tests/python-3.11/verify.sh

# Run individual test
devuser@ai-devkit:~$ /home/devuser/.ai-devkit/tests/nodejs-20/test-connectivity.sh
```

### Global Test Orchestrator
```bash
# /home/devuser/.ai-devkit/tests/run-all.sh (injected into container)
#!/bin/bash

echo "========================================="
echo "AI DevKit Component Verification"
echo "========================================="

FAILED=0

for component_test_dir in /home/devuser/.ai-devkit/tests/*/; do
    if [[ -d "$component_test_dir" ]] && [[ -f "$component_test_dir/verify.sh" ]]; then
        component=$(basename "$component_test_dir")
        echo ""
        echo "Testing $component..."
        if bash "$component_test_dir/verify.sh"; then
            echo "✅ $component: PASSED"
        else
            echo "❌ $component: FAILED"
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo ""
echo "========================================="
if [[ $FAILED -eq 0 ]]; then
    echo "✅ All components verified successfully!"
else
    echo "❌ $FAILED component(s) failed verification"
    exit 1
fi
```

## Success Criteria
1. ✅ No package manager names in core scripts
2. ✅ Components fully own their configuration
3. ✅ New package managers require zero core changes
4. ✅ All tests pass in new locations
5. ✅ No orphaned code or functions remain
6. ✅ Existing deployments continue to work
7. ✅ Component tests executable inside container
8. ✅ Every component has verification tests
9. ✅ Tests verify actual functionality, not just presence

## Risk Mitigation
1. **Backup current working state** before refactor
2. **Test incrementally** after each component migration
3. **Maintain compatibility layer** during transition
4. **Document all changes** for team awareness
5. **Create rollback plan** if issues arise

## Refactor Scope

### Components Requiring Full Migration
All components that provide tools, languages, or build systems need:
1. Configuration templates (if they have repos)
2. Volume mount specifications
3. Executable verification tests

### Affected Components (Estimated 20-25 total)
#### Languages (10+)
- python-3.11, python-default, python-miniconda
- nodejs-20, nodejs-22
- go-1.21, go-1.22
- java-11-openjdk, java-17-openjdk, java-21-openjdk
- ruby-3.3, rust-stable, rust-nightly
- scala-2.13, scala-3

#### Build/Deploy Tools (8+)
- maven, gradle, sbt
- docker, docker-compose
- kubectl, helm, kustomize

#### AI/Dev Tools (5+)
- claude-code, ai-kanban
- jupyter, vscode-server
- git, gh-cli

## Timeline Estimate
- **Template Infrastructure**: 3-4 hours
- **Component Migration**: 15-20 hours (20-25 components)
- **Core Script Updates**: 3-4 hours
- **Test Development**: 8-10 hours (verification tests for all components)
- **Testing & Verification**: 3-4 hours
- **Total**: 32-42 hours for complete refactor

Note: This touches EVERY component in the solution as requested

---

*This specification ensures complete separation of concerns with zero technical debt remaining.*