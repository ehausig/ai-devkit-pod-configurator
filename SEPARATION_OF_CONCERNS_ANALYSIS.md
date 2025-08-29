# Separation of Concerns Analysis: AI DevKit Pod Configurator

## Executive Summary

This analysis identifies significant separation of concerns violations in the AI DevKit Pod Configurator codebase, where component-specific code is hard-coded throughout core scripts rather than being properly encapsulated within the component architecture. The violations compromise maintainability, extensibility, and the clean architectural boundaries established by the existing component system.

## Current Violations Inventory

### 1. Hard-coded Package Manager References in Core Scripts

#### build-and-deploy.sh
- **Lines 544-585**: Hard-coded package manager string literals ("pypi", "npm", "maven2", "cargo", "go", "sbt", "gradle")
- **Lines 3544-3620**: Switch statements with hard-coded package manager names and file paths
- **Impact**: Adding new package managers requires modifying core deployment logic

#### lib/component-config-generator.sh
- **Lines 73-416**: Dedicated functions for each package manager:
  - `generate_pip_config()` - Python/pip specific
  - `generate_npm_config()` - Node.js/npm specific
  - `generate_go_env()` - Go specific
  - `generate_maven_settings()` - Maven specific
  - `generate_cargo_config()` - Rust/Cargo specific
- **Lines 390-410**: Switch statement on hard-coded format strings
- **Impact**: Each new package manager requires new core function implementation

#### lib/generate-dynamic-deployment.sh
- **Lines 70-130**: Hard-coded volume mount configurations for each package manager
- **Lines 238-320**: Hard-coded ConfigMap generation for each package manager
- **Impact**: Kubernetes deployment generation tightly coupled to specific tools

### 2. Hard-coded File Paths and Configuration Patterns

#### Configuration File Mapping
```bash
# From build-and-deploy.sh lines 3544-3620
"pypi") generated_file="$config_temp_dir/pip.conf" ;;
"npm") generated_file="$config_temp_dir/npmrc" ;;
"maven2") generated_file="$config_temp_dir/settings.xml" ;;
"cargo") generated_file="$config_temp_dir/cargo-config.toml" ;;
```

#### Volume Mount Paths
```bash
# From generate-dynamic-deployment.sh lines 74-119
"pip": /home/devuser/.config/pip/pip.conf
"npm": /home/devuser/.npmrc  
"maven": /home/devuser/.m2/settings.xml
"cargo": /home/devuser/.cargo/config.toml
```

### 3. Component-Specific Logic in Generic Functions

#### Repository Configuration Logic
- **lib/component-config-generator.sh**: Contains Python-specific pip.conf formatting
- **lib/component-config-generator.sh**: Contains Maven-specific XML generation
- **Impact**: Generic configuration system polluted with format-specific implementations

### 4. Environment Variable Hard-coding

#### Component-Specific Environment Variables
```bash
# From component YAML files and setup scripts
PIP_INDEX_URL, PIP_TRUSTED_HOST    # Python-specific
GOPROXY, GOSUMDB, GO111MODULE      # Go-specific  
NPM_CONFIG_REGISTRY               # Node.js-specific
```

## Current Component Architecture Analysis

### Existing Positive Patterns

#### 1. Component Metadata System
- **Location**: `components/` directory structure
- **Pattern**: Each component has a YAML descriptor with standardized fields
- **Strength**: Provides consistent metadata interface

#### 2. ai-devkit Subdirectory Pattern
- **Location**: `components/{category}/{component}/ai-devkit/`
- **Files**: `repos.yaml`, `env_vars.yaml`
- **Strength**: Component-owned configuration data

#### 3. Pre-build Script Hook System
- **Pattern**: `pre_build_script` field in component YAML
- **Usage**: Currently used by claude-code and ai-kanban components
- **Strength**: Allows component-specific build-time logic

#### 4. Repository Configuration Abstraction
- **Files**: `lib/config-reader.sh`, `lib/repository-loader.sh`, `lib/credential-manager.sh`
- **Pattern**: Generic repository loading with component-specific overrides
- **Strength**: Clean separation between user config and component defaults

### Architecture Capabilities Not Fully Utilized

#### 1. Pre-build Script Extensibility
- **Current**: Only used by 2 components
- **Potential**: Could handle all component-specific setup logic
- **Gap**: Core scripts still handle package manager setup directly

#### 2. Component Metadata Schema
- **Current**: Limited use of installation.repos.format field
- **Potential**: Could drive all configuration generation
- **Gap**: Core scripts duplicate format detection logic

#### 3. ai-devkit Directory Structure
- **Current**: Only repos.yaml and env_vars.yaml utilized
- **Potential**: Could contain all component-specific assets
- **Gap**: Volume mounts, configuration templates not componentized

## Impact Assessment

### Maintainability Issues
1. **Change Amplification**: Adding support for a new package manager requires changes across 4+ core files
2. **Knowledge Duplication**: Package manager knowledge scattered across multiple locations
3. **Testing Complexity**: Core script changes require testing all package manager combinations

### Extensibility Problems
1. **Closed for Extension**: Cannot add new package managers without modifying core code
2. **Tight Coupling**: Core deployment logic coupled to specific tool implementations
3. **Component Autonomy**: Components cannot fully own their configuration needs

### Consistency Risks
1. **Configuration Drift**: Same package manager handled differently across files
2. **Path Inconsistency**: Hard-coded paths may become inconsistent over time
3. **Format Evolution**: Package manager config formats may change independently

## Proposed Architecture Changes

### 1. Component-Owned Configuration Templates

#### New ai-devkit Structure
```
components/{category}/{component}/ai-devkit/
├── repos.yaml                    # Existing
├── env_vars.yaml                 # Existing  
├── config-templates/             # New
│   ├── pip.conf.template
│   ├── settings.xml.template
│   └── cargo-config.toml.template
├── volume-mounts.yaml            # New
└── deployment-patches.yaml       # New
```

#### Benefits
- Components own all their configuration artifacts
- Core scripts become generic processors
- New components can be added without core changes

### 2. Generic Configuration Generation Pipeline

#### Proposed Flow
```bash
# Replace hard-coded generators with:
for component in selected_components; do
    template_dir="$component/ai-devkit/config-templates"
    if [[ -d "$template_dir" ]]; then
        generate_configs_from_templates "$component" "$template_dir"
    fi
done
```

#### Implementation Strategy
- Replace package manager specific functions with template processor
- Use existing repository-loader.sh for data injection
- Maintain backward compatibility during transition

### 3. Volume Mount Configuration Schema

#### New volume-mounts.yaml Format
```yaml
mounts:
  - name: "pip-config"
    source_template: "pip.conf"
    container_path: "/home/devuser/.config/pip/pip.conf"
    subPath: "pip.conf"
  - name: "pip-cache"  
    container_path: "/home/devuser/.cache/pip"
    type: "emptyDir"
```

#### Integration Point
```bash
# In generate-dynamic-deployment.sh
for component in selected_components; do
    mount_config="$component/ai-devkit/volume-mounts.yaml"
    if [[ -f "$mount_config" ]]; then
        process_volume_mounts "$mount_config"
    fi
done
```

### 4. Enhanced Pre-build Script Usage

#### Expand Pre-build Responsibilities
- Move configuration file generation to pre-build scripts
- Allow components to handle their own Kubernetes patching
- Enable component-specific documentation processing

#### Example Implementation
```bash
# In component pre-build script
#!/bin/bash
# components/languages/python-3.11/ai-devkit/pre-build.sh

source "$LIB_DIR/repository-loader.sh"

# Generate pip.conf from component template
repos=$(resolve_repositories "PYTHON_3_11")
process_template "config-templates/pip.conf.template" "$repos" > "$OUTPUT_DIR/pip.conf"

# Register volume mount
register_volume_mount "pip-config" "$OUTPUT_DIR/pip.conf" "/home/devuser/.config/pip/pip.conf"
```

## Tech Debt Cleanup

### Orphaned Files and Scripts

The following files will become obsolete after the refactoring and should be removed:

#### Core Library Files
- **lib/component-config-generator.sh** - Contains all hard-coded package manager functions
  - `generate_pip_config()` function (lines 73-147)
  - `generate_npm_config()` function (lines 149-196) 
  - `generate_go_env()` function (lines 198-235)
  - `generate_maven_settings()` function (lines 237-322)
  - `generate_cargo_config()` function (lines 324-366)
  - `generate_component_config()` main dispatcher (lines 368-416)

#### Hard-coded Logic in Core Scripts
- **build-and-deploy.sh** - Switch statements and hard-coded mappings
  - Lines 3543-3549: Hard-coded file path mappings
  - Lines 3554-3587: Hard-coded volume mount configurations
  - Lines 3614-3617: Hard-coded config key mappings

- **lib/generate-dynamic-deployment.sh** - Package manager specific volume mounts
  - Lines 71-119: Hard-coded volume mount definitions for each package manager
  - Lines 238-320: Hard-coded ConfigMap generation logic

### Script Functions That Will Be Removed

#### From lib/component-config-generator.sh
- `generate_pip_config()` - Will be replaced by component template processing
- `generate_npm_config()` - Will be replaced by component template processing  
- `generate_go_env()` - Will be replaced by component template processing
- `generate_maven_settings()` - Will be replaced by component template processing
- `generate_cargo_config()` - Will be replaced by component template processing
- `generate_component_config()` - Will be replaced by generic template processor

#### From build-and-deploy.sh
- Switch statement logic for format-based file generation (lines 3543-3587)
- Hard-coded config mount array building (lines 3554-3586)

#### From lib/generate-dynamic-deployment.sh  
- Package manager specific volume mount generation functions
- Hard-coded ConfigMap content generation

### Duplicate and Redundant Code

#### Configuration Format Knowledge Duplication
- **build-and-deploy.sh** and **lib/component-config-generator.sh** both contain:
  - Package manager format strings ("pypi", "npm", "maven2", "cargo", "go")
  - File path knowledge (pip.conf, .npmrc, settings.xml, config.toml)
  - Container mount path knowledge

#### Repository URL Processing Duplication
- Multiple functions implement similar URL translation logic
- Authentication handling duplicated across package managers
- Container host resolution logic repeated

### Files for Consolidation

#### Test Files Requiring Migration
- **tests/validate-python-nexus.sh** - Component-specific validation
- **tests/validate-nodejs-nexus.sh** - Component-specific validation
- **tests/validate-all-nexus.sh** - Orchestration script for component validation

These should be moved to respective component directories:
- `components/languages/python-3.11/ai-devkit/tests/validate-nexus.sh`
- `components/languages/nodejs-20/ai-devkit/tests/validate-nexus.sh`

## Component Testing Strategy

### Current Test Structure Issues

The current testing approach has several problems:
1. **Component-specific tests in global tests/ folder** - Violates component autonomy
2. **Hard-coded package manager knowledge in test scripts** - Creates maintenance burden
3. **No component self-testing capability** - Components cannot validate their own configuration
4. **Centralized test orchestration** - Does not scale with component additions
5. **Manual kubectl cp required** - Users must manually copy tests into container
6. **No runtime verification** - Cannot easily verify components work inside container

### Proposed Component Test Structure

#### Individual Component Test Directory
```
components/{category}/{component}/ai-devkit/
├── repos.yaml                    # Existing
├── env_vars.yaml                 # Existing  
├── config-templates/             # New
│   ├── pip.conf.template
│   └── pip.conf.schema.json
├── volume-mounts.yaml            # New (includes test injection)
├── tests/                        # New (injected into container)
│   ├── verify.sh                 # Main verification script
│   ├── test-config.sh            # Component config validation
│   ├── test-connectivity.sh      # Repository connectivity test
│   ├── test-installation.sh      # Package installation test
│   └── test-functionality.sh     # Actual tool functionality test
└── deployment-patches.yaml       # New
```

#### Test Injection into Container
Tests are automatically mounted into the container at:
```
/home/devuser/.ai-devkit/tests/{component-name}/
```
Users can execute tests directly without kubectl cp:
```bash
# Inside container
devuser@ai-devkit:~$ ~/.ai-devkit/tests/python-3.11/verify.sh
devuser@ai-devkit:~$ ~/.ai-devkit/tests/run-all.sh
```

#### Component Test Categories

**Configuration Generation Tests**
- Validate that component templates generate valid configuration files
- Test template variable substitution
- Verify configuration file schema compliance
- Example: `components/languages/python-3.11/ai-devkit/tests/test-config.bats`

**Connectivity Tests**  
- Test repository accessibility from container
- Validate authentication mechanisms
- Check proxy/firewall configurations
- Example: `components/languages/python-3.11/ai-devkit/tests/validate-connectivity.sh`

**Installation Tests**
- Test actual package installation using generated configuration
- Validate package manager behavior with custom repositories
- Test package resolution and dependency handling
- Example: `components/languages/python-3.11/ai-devkit/tests/validate-installation.sh`

#### Self-Testing Component Interface

**Standard Test Commands**
Each component should support standardized test commands:

```bash
# Run all component tests
./ai-devkit/tests/run-all-tests.sh

# Test specific aspects
./ai-devkit/tests/validate-config.sh      # Config generation
./ai-devkit/tests/validate-connectivity.sh # Repository access
./ai-devkit/tests/validate-installation.sh # Package installation
```

**Test Integration with Build System**
```bash
# In component pre-build script
#!/bin/bash
# components/languages/python-3.11/ai-devkit/pre-build.sh

# Generate configuration from templates
process_component_templates

# Run component self-tests
if [[ "${RUN_COMPONENT_TESTS:-false}" == "true" ]]; then
    ./ai-devkit/tests/run-all-tests.sh
fi

# Register generated assets
register_volume_mounts "$COMPONENT_DIR/ai-devkit/volume-mounts.yaml"
```

#### Example Component Tests

**Python Component Config Test (components/languages/python-3.11/ai-devkit/tests/test-config.bats)**
```bash
#!/usr/bin/env bats

setup() {
    # Setup test environment
    export TEST_REPOS='[{"name":"test","url":"http://test.com"}]'
    export OUTPUT_DIR="/tmp/test-config-$$"
    mkdir -p "$OUTPUT_DIR"
}

teardown() {
    rm -rf "$OUTPUT_DIR"
}

@test "pip.conf template generates valid configuration" {
    # Process template with test data
    process_template "config-templates/pip.conf.template" "$TEST_REPOS" > "$OUTPUT_DIR/pip.conf"
    
    # Validate generated config
    [[ -f "$OUTPUT_DIR/pip.conf" ]]
    grep -q "index-url = http://test.com" "$OUTPUT_DIR/pip.conf"
}

@test "pip.conf validates against schema" {
    # Generate config and validate schema
    process_template "config-templates/pip.conf.template" "$TEST_REPOS" > "$OUTPUT_DIR/pip.conf"
    validate_config_schema "$OUTPUT_DIR/pip.conf" "config-templates/pip.conf.schema.json"
}
```

**Python Component Installation Test**
```bash
#!/bin/bash
# components/languages/python-3.11/ai-devkit/tests/validate-installation.sh

set -e

echo "Testing Python package installation with generated configuration..."

# Use the generated pip.conf from build process
if [[ ! -f "/home/devuser/.config/pip/pip.conf" ]]; then
    echo "ERROR: pip.conf not found - configuration generation failed"
    exit 1
fi

# Test package installation in isolated environment
temp_venv="/tmp/test_venv_$$"
python3 -m venv "$temp_venv"
source "$temp_venv/bin/activate"

# Install test package
if pip install requests --no-cache-dir; then
    echo "✓ Package installation successful"
else
    echo "✗ Package installation failed"
    exit 1
fi

deactivate
rm -rf "$temp_venv"
```

### Global Test Orchestration

**Component Test Discovery**
```bash
# New global test runner: tests/run-component-tests.sh
#!/bin/bash

for component_dir in components/*/*/; do
    if [[ -d "$component_dir/ai-devkit/tests" ]]; then
        echo "Running tests for $(basename "$component_dir")..."
        cd "$component_dir"
        ./ai-devkit/tests/run-all-tests.sh
        cd - > /dev/null
    fi
done
```

## Implementation Recommendations

### Phase 1: Infrastructure Setup (Low Risk)
1. **Add Template Processing Library**
   - Create `lib/template-processor.sh`
   - Implement variable substitution engine
   - Add template validation

2. **Extend ai-devkit Directory Schema**
   - Define `config-templates/` subdirectory
   - Define `volume-mounts.yaml` schema
   - Create migration utilities

3. **Create Registration System**
   - Add `register_volume_mount()` function
   - Add `register_config_map()` function
   - Maintain state in temporary files

### Phase 2: Component Migration (Medium Risk)
1. **Migrate High-Value Components First**
   - Start with python-3.11 (most complex configuration)
   - Move to nodejs-20 and go-1.22
   - Learn from early migrations

2. **Test Migration Strategy**
   - Move component-specific tests from tests/ to component directories
   - Create component test directories: `{component}/ai-devkit/tests/`
   - Update test scripts to use component-specific paths
   - Maintain global test orchestration in tests/run-component-tests.sh

3. **Maintain Parallel Systems**
   - Keep existing hard-coded generators as fallback
   - Add feature flag for new system
   - Gradual rollout with testing

4. **Update Component YAMLs**
   - Add `installation.config_generation: "component"` flag
   - Deprecate but maintain format field
   - Update component documentation

### Phase 3: Core Script Cleanup (High Risk)
1. **Remove Hard-coded Logic**
   - Replace switch statements with component iteration
   - Remove package manager specific functions from lib/component-config-generator.sh
   - Delete obsolete functions: generate_pip_config, generate_npm_config, etc.
   - Simplify deployment generation in lib/generate-dynamic-deployment.sh

2. **Tech Debt Cleanup per Component**
   - Remove hard-coded switch statements from build-and-deploy.sh (lines 3543-3587)
   - Clean up volume mount generation in generate-dynamic-deployment.sh
   - Remove format-specific logic from core scripts

3. **Schema Validation**
   - Add validation for component templates
   - Verify volume mount specifications
   - Test configuration generation

4. **Test System Migration**
   - Remove global tests/validate-*-nexus.sh files
   - Verify all component tests are working in their new locations
   - Update CI/CD to run component tests

5. **Documentation Updates**
   - Update component development guide
   - Create configuration template reference
   - Update troubleshooting procedures

### Phase 4: Advanced Features (Enhancement)
1. **Template Language Extensions**
   - Add conditional logic support
   - Support for complex data transformations
   - Environment-specific variations

2. **Configuration Validation**
   - Schema validation for generated configs
   - Runtime configuration testing
   - Automated config drift detection

## Benefits and Risks

### Benefits
1. **True Component Autonomy**: Components fully own their configuration needs
2. **Open/Closed Principle**: Core system closed for modification, open for extension
3. **Reduced Coupling**: Core scripts independent of specific tools
4. **Better Testing**: Component-specific logic can be tested independently
5. **Easier Maintenance**: Changes localized to individual components

### Risks
1. **Complexity Introduction**: Template system adds complexity
2. **Migration Challenges**: Risk of breaking existing deployments
3. **Testing Overhead**: More complex testing matrix
4. **Developer Learning Curve**: New patterns to learn

### Risk Mitigation Strategies
1. **Incremental Migration**: Maintain backward compatibility during transition
2. **Comprehensive Testing**: Extensive integration testing for each component
3. **Feature Flags**: Ability to fall back to old system if issues arise
4. **Clear Documentation**: Detailed guides for component developers
5. **Validation Tools**: Automated checking of component configurations

## Component Test Requirements

### Mandatory Test Coverage
Every component that provides tools, languages, or build systems MUST include:

1. **verify.sh** - Main test orchestrator that runs all component tests
2. **test-config.sh** - Validates configuration files are correctly generated
3. **test-connectivity.sh** - Verifies repository/network connectivity
4. **test-installation.sh** - Tests actual package/dependency installation
5. **test-functionality.sh** - Verifies the tool actually works (not just installed)

### Test Execution Requirements
- Tests must be executable inside the container without manual copying
- Tests must provide clear pass/fail status with meaningful output
- Tests must handle both online and offline scenarios gracefully
- Tests must complete within reasonable time limits (< 60 seconds per component)

### Example Test Implementation
```bash
#!/bin/bash
# components/languages/python-3.11/ai-devkit/tests/verify.sh
set -e

echo "Verifying Python 3.11 installation..."

# Check version
python3.11 --version || { echo "❌ Python 3.11 not found"; exit 1; }

# Check pip works
pip3.11 list > /dev/null || { echo "❌ pip not functional"; exit 1; }

# Test package installation
pip3.11 install --no-cache-dir six || { echo "❌ Cannot install packages"; exit 1; }

# Test functionality
python3.11 -c "import six; print(six.__version__)" || { echo "❌ Installed packages not working"; exit 1; }

echo "✅ Python 3.11 verified successfully"
```

## Migration Checklist

### Files to be Deleted
- [ ] `lib/component-config-generator.sh` - Entire file becomes obsolete
- [ ] `tests/validate-python-nexus.sh` - Moved to component directory
- [ ] `tests/validate-nodejs-nexus.sh` - Moved to component directory  
- [ ] `tests/validate-all-nexus.sh` - Replaced by component test orchestration

### Functions to be Removed
- [ ] `generate_pip_config()` from lib/component-config-generator.sh
- [ ] `generate_npm_config()` from lib/component-config-generator.sh
- [ ] `generate_go_env()` from lib/component-config-generator.sh
- [ ] `generate_maven_settings()` from lib/component-config-generator.sh
- [ ] `generate_cargo_config()` from lib/component-config-generator.sh
- [ ] `generate_component_config()` from lib/component-config-generator.sh
- [ ] Switch statement logic from build-and-deploy.sh (lines 3543-3587)
- [ ] Hard-coded volume mount logic from lib/generate-dynamic-deployment.sh

### Tests to be Migrated
- [ ] Move `tests/validate-python-nexus.sh` to `components/languages/python-3.11/ai-devkit/tests/validate-nexus.sh`
- [ ] Move `tests/validate-nodejs-nexus.sh` to `components/languages/nodejs-20/ai-devkit/tests/validate-nexus.sh`
- [ ] Create component test runner: `components/{component}/ai-devkit/tests/run-all-tests.sh`
- [ ] Create global test orchestrator: `tests/run-component-tests.sh`
- [ ] Add configuration generation tests for each component
- [ ] Add component self-testing to pre-build scripts

### Documentation to be Updated
- [ ] Update component development guide with new test structure
- [ ] Document component template system
- [ ] Create component testing guidelines
- [ ] Update troubleshooting guide with component-specific sections
- [ ] Document migration process for existing components
- [ ] Update API documentation for template processing system

### New Files to be Created
- [ ] `lib/template-processor.sh` - Generic template processing library
- [ ] Component template directories: `{component}/ai-devkit/config-templates/`
- [ ] Component volume mount specs: `{component}/ai-devkit/volume-mounts.yaml`
- [ ] Component test directories: `{component}/ai-devkit/tests/`
- [ ] Template validation schemas: `{component}/ai-devkit/config-templates/*.schema.json`

### Configuration Changes
- [ ] Add `installation.config_generation: "component"` to component YAMLs
- [ ] Create feature flag for new template system
- [ ] Update CI/CD pipeline to run component tests
- [ ] Configure test environments for component isolation

## Success Metrics

### Technical Metrics
1. **Lines of Hard-coded Logic**: Reduce from ~400 to <50
2. **Core Script Modification Required**: Zero for new package managers
3. **Component Test Independence**: 100% of components testable in isolation
4. **Configuration Consistency**: Zero drift between duplicate configurations
5. **Obsolete Code Removal**: 100% of identified tech debt cleaned up
6. **Test Migration**: 100% of component tests moved to component directories

### Development Metrics
1. **New Component Time**: Reduce setup time by 75%
2. **Change Impact**: Localize changes to single components
3. **Bug Isolation**: Component-specific issues don't affect core system
4. **Documentation Quality**: All components self-documenting
5. **Test Execution Time**: Component tests run in parallel, reducing total time
6. **Component Autonomy**: Components can validate their own configuration

### Post-Migration Validation
1. **Code Cleanup Verification**: Automated checks to ensure no orphaned code remains
2. **Function Reference Auditing**: Scan for any remaining calls to deleted functions
3. **Import/Source Statement Cleanup**: Remove any references to deleted files
4. **Documentation Link Validation**: Update all documentation links to moved/deleted files

## Ensuring No Orphaned Code Remains

### Automated Cleanup Verification

**Script to Find Orphaned References**
```bash
#!/bin/bash
# scripts/find-orphaned-references.sh

echo "Checking for references to deleted functions..."

# Functions that should be removed
DELETED_FUNCTIONS=(
    "generate_pip_config"
    "generate_npm_config" 
    "generate_go_env"
    "generate_maven_settings"
    "generate_cargo_config"
    "generate_component_config"
)

for func in "${DELETED_FUNCTIONS[@]}"; do
    echo "Searching for references to $func:"
    if grep -r "$func" --exclude-dir=.git . | grep -v "# DELETED:" ; then
        echo "  ❌ Found orphaned references to $func"
    else
        echo "  ✅ No references to $func found"
    fi
done

echo ""
echo "Checking for source statements to deleted files..."

# Files that should be removed
DELETED_FILES=(
    "lib/component-config-generator.sh"
    "tests/validate-python-nexus.sh"
    "tests/validate-nodejs-nexus.sh"
    "tests/validate-all-nexus.sh"
)

for file in "${DELETED_FILES[@]}"; do
    echo "Searching for source/import of $file:"
    if grep -r "source.*$file\|\\. .*$file\|include.*$file" --exclude-dir=.git . ; then
        echo "  ❌ Found orphaned source statements for $file"
    else
        echo "  ✅ No source statements for $file found"  
    fi
done
```

**Hard-coded String Cleanup Verification**
```bash
#!/bin/bash
# scripts/verify-hardcode-cleanup.sh

echo "Checking for remaining hard-coded package manager references..."

# Package manager strings that should be removed from core scripts
HARDCODED_STRINGS=(
    '"pypi"'
    '"npm"'
    '"maven2"' 
    '"cargo"'
    '"go"'
)

# Core files that should be cleaned
CORE_FILES=(
    "build-and-deploy.sh"
    "lib/generate-dynamic-deployment.sh"
)

for file in "${CORE_FILES[@]}"; do
    echo "Checking $file:"
    for string in "${HARDCODED_STRINGS[@]}"; do
        if grep -n "$string" "$file" 2>/dev/null; then
            echo "  ❌ Found hard-coded $string in $file"
        fi
    done
done

echo ""
echo "Checking for hard-coded switch statements..."
if grep -A10 -B5 'case.*format.*in' build-and-deploy.sh 2>/dev/null; then
    echo "  ❌ Found remaining format-based switch statements"
else
    echo "  ✅ No format-based switch statements found"
fi
```

### Migration Verification Checklist

**Pre-Migration State Capture**
- [ ] Create backup of all files to be modified/deleted
- [ ] Document all current function dependencies with `grep -r "function_name" .`
- [ ] List all current hard-coded references with automated scan
- [ ] Export current test results for comparison

**During Migration Validation**
- [ ] Verify each component can generate its own configuration
- [ ] Confirm component tests run successfully in new locations
- [ ] Test that core scripts work without deleted functions
- [ ] Validate that no core script modifications needed for new components

**Post-Migration Cleanup Verification**
- [ ] Run orphaned reference detection script
- [ ] Verify no imports/sources point to deleted files
- [ ] Confirm all hard-coded switch statements removed from core scripts
- [ ] Test that adding a new package manager requires zero core changes
- [ ] Validate all component tests pass in their new locations
- [ ] Confirm global test orchestration works with component tests

**Regression Testing**
- [ ] Deploy existing components with new system
- [ ] Verify all package managers still work correctly
- [ ] Test repository configuration generation for all components
- [ ] Confirm Kubernetes deployments generate correctly
- [ ] Validate that authentication still works for all package managers

## Conclusion

The current architecture has strong foundations with the component system and ai-devkit directories, but suffers from significant separation of concerns violations. The proposed changes leverage existing architectural strengths while eliminating hard-coded dependencies. 

The phased implementation approach minimizes risk while delivering immediate benefits. Success requires careful attention to backward compatibility and comprehensive testing, but the long-term maintainability and extensibility gains justify the investment.

This refactoring will transform the system from a monolithic deployment script with component plugins to a true component-driven architecture where the core system serves as a generic orchestrator for component-owned functionality.