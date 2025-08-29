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
    ├── tests/                     # NEW: Component tests
    │   ├── test-config.sh
    │   ├── test-connectivity.sh
    │   └── test-installation.sh
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
# Declares where configs should be mounted
mounts:
  - name: "pip-config"
    source: "pip.conf"
    target: "/home/devuser/.config/pip/pip.conf"
    type: "file"
  - name: "python-env"
    source: "python-env.sh"
    target: "/home/devuser/.config/python-env.sh"
    type: "file"
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
```bash
# ai-devkit/tests/test-config.sh
#!/bin/bash
source "$LIB_DIR/template-processor.sh"

test_pip_config_generation() {
    local repos='[{"url": "https://pypi.org/simple"}]'
    process_template "../config-templates/pip.conf.j2" "$repos" "/tmp/test-pip.conf"
    
    # Verify the generated config
    grep -q "index-url = https://pypi.org/simple" /tmp/test-pip.conf
}
```

### Global Test Orchestration
```bash
# tests/run-all-component-tests.sh
#!/bin/bash
for component in components/*/*/ai-devkit/tests; do
    if [[ -d "$component" ]]; then
        echo "Running tests for $(dirname $(dirname $component))"
        for test in "$component"/*.sh; do
            bash "$test"
        done
    fi
done
```

## Success Criteria
1. ✅ No package manager names in core scripts
2. ✅ Components fully own their configuration
3. ✅ New package managers require zero core changes
4. ✅ All tests pass in new locations
5. ✅ No orphaned code or functions remain
6. ✅ Existing deployments continue to work

## Risk Mitigation
1. **Backup current working state** before refactor
2. **Test incrementally** after each component migration
3. **Maintain compatibility layer** during transition
4. **Document all changes** for team awareness
5. **Create rollback plan** if issues arise

## Timeline Estimate
- **Template Infrastructure**: 2-3 hours
- **Component Migration**: 4-5 hours (8 components)
- **Core Script Updates**: 2-3 hours
- **Testing & Verification**: 2-3 hours
- **Total**: 10-14 hours for complete refactor

---

*This specification ensures complete separation of concerns with zero technical debt remaining.*