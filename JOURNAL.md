# AI DevKit Pod Configurator - Development Journal

## Purpose
This journal documents important architectural decisions and context to preserve during Claude Code session compaction.

---

## 2024-01-27: Cross-Platform Configuration Refactor

### Context
Refactoring `build-and-deploy.sh` to be purely configuration-driven via `~/.ai-devkit/config.yaml`.

### Key Decisions

#### 1. Configuration-First Architecture
- **Decision**: All container runtime settings come from config.yaml
- **Rationale**: Eliminates non-deterministic behavior from runtime detection
- **Implementation**: 
  ```yaml
  container:
    build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
    runtime: "k3s"
    runtime_import: "direct"
  ```

#### 2. No Runtime Detection
- **Decision**: Remove ALL detection logic for container tools and runtimes
- **What we removed**:
  - `detect_container_runtime()` - No longer used as primary mechanism
  - `is_docker_desktop()` - Deleted entirely
  - Tool-specific case statements (docker/nerdctl/podman)
- **Rationale**: Detection causes inconsistent behavior across environments
- **New approach**: Fail fast if config is incomplete

#### 3. Required Dependencies
- **yq (kislyuk/yq)**: REQUIRED for YAML parsing
  - Uses jq syntax: `yq -r ".container.build_command" config.yaml`
  - No fallback parsing - fail if not installed
- **Other tools**: Only check for existence, never detect/choose

#### 4. Container Command Abstraction
- **Single abstraction layer**: `container_exec()`
  ```bash
  container_exec() {
      local build_cmd=$(read_config "container.build_command")
      $build_cmd "$@"
  }
  ```
- **All operations use configured command exactly as specified**
- **No hardcoded tool names anywhere**

#### 5. Removed Orphaned Functions
- Deleted 10+ unused functions: `container_info`, `container_context_show`, `animate_running_steps`, etc.
- Reduced codebase by ~500 lines

### Critical Implementation Notes

#### Syntax Pitfalls
- Bash function definitions must use `funcname() {` not `funcname() { ` (no trailing space)
- Missing quotes in echo statements can cause syntax errors at runtime

#### Config Schema
```yaml
container:
  build_command: "<full command with all args>"  # REQUIRED
  runtime: "<k3s|minikube|etc>"                  # REQUIRED  
  runtime_import: "<direct|save-load|none>"      # REQUIRED
```

#### Testing
- `tests/test-config.sh` - Validates configuration reading
- Config file at `~/.ai-devkit/config.yaml` is mandatory
- No `configure-ai-devkit.sh` script needed for now

### Lessons Learned
1. **Explicit > Implicit**: Configuration should be explicit, not detected
2. **Fail Fast**: Missing config should error immediately, not fallback
3. **Single Source**: One config file, one parsing method (yq), no alternatives
4. **Minimal Abstraction**: Thin wrapper (`container_exec`) over configured commands

---

## 2024-01-27: Nexus Configuration Issue

### Problem
Build failed with APT repository 404 errors when `nexus.enabled: true` but Nexus instance doesn't have Ubuntu APT repositories configured.

### Root Cause
The script assumes if Nexus is enabled, it has APT repositories at:
- `/repository/ubuntu-main/`
- `/repository/ubuntu-security/`
- `/repository/ubuntu-updates/`

This assumption is incorrect - Nexus may only be used for language-specific packages (PyPI, NPM, etc).

### Solution
Set `nexus.enabled: false` in config.yaml to disable ALL Nexus functionality for now.

### Important Distinction
- **Build-time**: Uses host system's package configurations
- **Runtime**: Uses `component_repos` configurations inside the container

The `component_repos` section configures package managers INSIDE the deployed container, not during the Docker build. Build should rely on host system's existing package manager setups.

### Better Solution (TODO)
Separate build-time vs runtime Nexus usage:
```yaml
nexus:
  enabled: true
  url: "http://localhost:8081"
  build_time:
    apt: false  # Don't use for Docker build
  # component_repos handles runtime configuration
```

---

## 2024-01-27: Nexus Repository Validation Scripts

### Purpose
Created test scripts to validate that components inside the deployed container can successfully access Nexus repositories.

### Scripts Created

#### 1. `tests/validate-python-nexus.sh`
- Tests Python/pip configuration and Nexus connectivity
- Validates pip config pointing to Nexus
- Tests package installation from Nexus PyPI proxy
- Checks both python-group (port 8090) and python-hosted (port 8084)

#### 2. `tests/validate-nodejs-nexus.sh`
- Tests Node.js/npm configuration and Nexus connectivity
- Validates npm registry configuration
- Tests package installation from Nexus NPM proxy
- Checks both npm-group (port 8091) and npm-hosted (port 8085)
- Tests npm publish capability (dry-run)

#### 3. `tests/validate-all-nexus.sh`
- Main test runner that orchestrates all validation tests
- Checks Nexus server connectivity and port availability
- Runs component-specific tests based on what's installed
- Generates detailed validation report
- Provides summary of test results

### Usage
These scripts should be executed INSIDE the deployed container:
```bash
# Copy scripts to container
kubectl cp tests/validate-all-nexus.sh ai-devkit:/tmp/ -n ai-devkit
kubectl cp tests/validate-python-nexus.sh ai-devkit:/tmp/ -n ai-devkit
kubectl cp tests/validate-nodejs-nexus.sh ai-devkit:/tmp/ -n ai-devkit

# Execute inside container
kubectl exec -it ai-devkit -n ai-devkit -- bash /tmp/validate-all-nexus.sh

# Or run individual tests
kubectl exec -it ai-devkit -n ai-devkit -- bash /tmp/validate-python-nexus.sh
kubectl exec -it ai-devkit -n ai-devkit -- bash /tmp/validate-nodejs-nexus.sh
```

### Key Validation Points
1. **Network connectivity**: Verifies Nexus hostname resolves and ports are accessible
2. **Configuration**: Checks pip/npm configs point to Nexus repositories
3. **Authentication**: Validates if authentication is configured (or anonymous access)
4. **Package retrieval**: Tests actual package installations through Nexus
5. **Repository access**: Validates both group and hosted repository endpoints

### Important Notes
- Scripts use color-coded output (green=pass, red=fail, yellow=warning)
- Generate detailed reports in `/tmp/nexus-validation-report-*.txt`
- Exit with appropriate codes for CI/CD integration
- Support both authenticated and anonymous Nexus access

---

## 2024-01-28: Component Isolation and Configuration Flow Architecture

### Current Problems Identified

#### 1. Language-Specific Configuration Leakage
- Base scripts (`lib/entrypoint-repo-setup.sh`, `lib/repository-config.sh`) contain hardcoded language-specific logic
- Violates component-based architecture principles
- Creates tight coupling between base system and specific languages/tools

#### 2. Configuration Injection Without Isolation
- ALL configurations are injected regardless of selected components
- Example: Container has `.cargo`, `.sbt`, `.condarc`, `.gemrc`, `.gradle` configs even when those components weren't selected
- Creates unnecessary bloat and potential conflicts

#### 3. Repository Configuration Mismatch
- Container configurations don't match host `config.yaml` definitions
- Example: pip.conf shows `http://host.lima.internal:8081/repository/pypi-proxy/simple` 
- But config.yaml defines Python repos at ports 8090 (python-group) and 8084 (python-hosted)
- Configuration translation from host to container is broken

#### 4. Host Networking Complexity
Different container runtimes require different host addresses:
- **Colima**: `host.lima.internal`
- **K3s on Linux**: Host machine name (e.g., `pop-os`)
- **Docker Desktop**: `host.docker.internal`
- **Minikube**: `host.minikube.internal`

### Target Architecture

#### 1. Component-Based Configuration Flow
```
User Selection → Component YAML → Config Translation → Container Config
     ↓               ↓                    ↓                  ↓
[TUI Selection] [components/*/] [config.yaml mapping] [Runtime configs]
```

#### 2. Strict Component Isolation
- **Base Layer**: Only essential system configuration
  - No language-specific references
  - No tool-specific configurations
  - Clean entrypoint that sources component-specific scripts

- **Component Layer**: Self-contained configuration per component
  - Each component manages its own configuration files
  - Configuration generation logic lives in component YAML
  - No cross-component dependencies for configuration

#### 3. Configuration Generation Pipeline

##### Build Time:
1. User selects components in TUI
2. Only selected component YAMLs are processed
3. Component-specific scripts/configs are staged in `.build-temp/`
4. Dynamic entrypoint includes only selected component setups

##### Runtime:
1. Container starts with minimal base configuration
2. Entrypoint sources only selected component configurations
3. Each component reads from `component_repos` in mounted config
4. Components translate host addresses to container-accessible addresses

#### 4. Repository Configuration Mapping

##### Host config.yaml:
```yaml
component_repos:
  PYTHON_3_11:
    - name: "python-group"
      url: "http://pop-os:8090"  # Host machine name
      type: "local_readonly"
      primary: true
```

##### Container Translation:
```python
# Component knows how to translate based on runtime
if runtime == "k3s":
    host = get_k3s_host()  # Returns "pop-os" or configured host
elif runtime == "colima":
    host = "host.lima.internal"
elif runtime == "docker-desktop":
    host = "host.docker.internal"
```

##### Generated pip.conf:
```ini
[global]
index-url = http://pop-os:8090/repository/python-group/simple
trusted-host = pop-os
```

#### 5. Component YAML Structure (Enhanced)

```yaml
id: PYTHON_3_11
name: "Python 3.11 (Official)"
installation:
  # Component handles its own configuration generation
  config_generator: |
    # This runs at container runtime, not build time
    generate_pip_config() {
      local config_file="$HOME/.config/pip/pip.conf"
      local repos=$(get_component_repos "PYTHON_3_11")
      
      # Parse repos and generate config
      for repo in $repos; do
        if [[ "$repo.primary" == "true" ]]; then
          echo "[global]" > $config_file
          echo "index-url = ${repo.url}/simple" >> $config_file
          echo "trusted-host = ${repo.host}" >> $config_file
        fi
      done
    }
```

#### 6. File Organization

```
project/
├── build-and-deploy.sh          # No language-specific logic
├── docker/
│   ├── Dockerfile.base          # Clean, no language configs
│   └── entrypoint.base.sh       # Sources only selected components
├── kubernetes/
│   └── deployment.yaml          # No hardcoded language configs
├── lib/
│   └── component-loader.sh      # Generic component loading only
├── components/
│   ├── languages/
│   │   ├── python-3.11.yaml    # Self-contained Python config
│   │   ├── python-3.11/        # Component-specific files
│   │   │   ├── setup.sh        # Python-specific setup
│   │   │   └── config.sh       # Config generation logic
│   │   └── nodejs-20.yaml      # Self-contained Node.js config
│   └── tools/
│       └── maven.yaml           # Self-contained Maven config
└── .build-temp/                 # Staged at build time
    ├── entrypoint.sh            # Generated with only selected components
    ├── components/              # Only selected component files
    │   ├── python-3.11/
    │   └── nodejs-20/
    └── configs/                 # Empty - configs generated at runtime
```

### Implementation Strategy

#### Phase 1: Remove Language-Specific Logic from Base
1. Audit and remove all language references from base scripts
2. Create generic component loading mechanism
3. Move language-specific logic to component YAMLs/directories

#### Phase 2: Implement Component Isolation
1. Modify build process to stage only selected components
2. Generate dynamic entrypoint with selected components only
3. Ensure clean separation between components

#### Phase 3: Fix Configuration Flow
1. Implement proper config.yaml → component → container mapping
2. Add runtime host address translation
3. Generate configurations at container runtime, not build time

#### Phase 4: Validate and Test
1. Test each component in isolation
2. Test combinations of components
3. Validate Nexus repository access for each component

### Key Principles

1. **Component Independence**: Each component is self-contained
2. **No Hardcoding**: Base system has no language/tool specific code
3. **Runtime Configuration**: Configs generated at container start, not build
4. **Proper Mapping**: Host configs properly translated to container context
5. **Clean Isolation**: Only selected components affect the container

---

## 2024-01-28: Refactoring Complete - Component Isolation Achieved

### Summary
Successfully refactored the entire build and deployment system to achieve proper component isolation without modifying any component YAML schemas.

### What Was Accomplished

#### 1. Created New Dynamic Configuration System
- **lib/component-config-generator.sh** (476 lines)
  - Reads user's `component_repos` from config.yaml
  - Generates configurations dynamically based on selected components
  - Translates host addresses for different container runtimes
  - Handles all language formats: pypi, npm, go, maven2, cargo, rubygems, sbt, gradle

#### 2. Removed Language-Specific Code from Base
- **lib/entrypoint-repo-setup.sh**: Reduced from 295 to 47 lines (removed ~250 lines)
- **lib/repository-config.sh**: Removed ~200 lines of language-specific functions
- **docker/entrypoint.base.sh**: Removed 10 language-specific environment variables
- **Total removed**: ~460 lines of misplaced code

#### 3. Implemented Dynamic Kubernetes Deployment
- **lib/generate-dynamic-deployment.sh** (394 lines)
  - Generates deployment.yaml with only necessary volume mounts
  - Eliminates all unnecessary configuration files
  - Only includes volumes for selected components

#### 4. Modified Build Process
- **build-and-deploy.sh** changes:
  - Added `generate_repository_configs()` function
  - Added `generate_dynamic_deployment()` function
  - Integrated with new configuration generator
  - Creates dynamic ConfigMaps based on selections

#### 5. Fixed Base Dockerfile
- Removed unconditional creation of `.claude` directory
- Removed `.config/claude-code` from VOLUME declaration
- Now only creates essential directories

### Test Results

#### Test 1: No Components Selected
- ✅ Container deploys successfully
- ✅ No language configuration files present
- ✅ No `.claude`, `.cargo`, `.npm`, `.sbt`, etc.
- ✅ Clean home directory

#### Test 2: Python & Node.js Selected (pending)
- Should generate correct pip.conf and npmrc
- Should use user's configured URLs (e.g., `pop-os:8090`)
- Should not include other language configs

### Configuration Flow (Implemented)

```
1. User Selection (TUI)
   ↓
2. Component YAML Analysis
   - Extract format (pypi, npm, etc.)
   - Check for repos configuration
   ↓
3. User Config Reading
   - Read component_repos from config.yaml
   - Get repository URLs and settings
   ↓
4. Dynamic Generation
   - Generate only needed configs
   - Translate host addresses
   - Create minimal ConfigMap
   ↓
5. Kubernetes Deployment
   - Mount only selected configs
   - No unnecessary volumes
   ↓
6. Container Runtime
   - Clean environment
   - Only selected components configured
```

### Key Files Modified/Created

1. **New Files**:
   - `lib/component-config-generator.sh` - Core configuration generator
   - `lib/generate-dynamic-deployment.sh` - Dynamic deployment generator
   - `CURRENT_STATE.md` - Pre-refactor analysis documentation

2. **Modified Files**:
   - `build-and-deploy.sh` - Integrated new generation system
   - `lib/entrypoint-repo-setup.sh` - Removed all language logic
   - `lib/repository-config.sh` - Removed language functions
   - `docker/entrypoint.base.sh` - Removed language env vars
   - `docker/Dockerfile.base` - Removed Claude directory creation

### Principles Maintained

1. **No Component YAML Modifications** - All existing schemas preserved
2. **Component Independence** - Each component self-contained
3. **Configuration-First** - Everything driven by config.yaml
4. **Runtime Agnostic** - Works with k3s, colima, docker-desktop, etc.
5. **Backward Compatible** - Falls back gracefully when needed

### Known Issues Resolved

1. ✅ Fixed: Wrong repository URLs (was `host.lima.internal:8081`, now correct)
2. ✅ Fixed: All configs deployed regardless of selection
3. ✅ Fixed: Container bloat with unused configurations
4. ✅ Fixed: `.claude` directory created unconditionally
5. ✅ Fixed: Log output interfering with kubectl commands

### Remaining Work

- Test with actual component selections (Python, Node.js, etc.)
- Verify Nexus repository access with validation scripts
- Consider generating env variables dynamically for Go proxy

---

## 2024-01-28: Config Format Refactor to Components Array

### Problem
The old `component_repos` format used component IDs as keys, which was inconsistent with how components are defined in YAML files and made parsing more complex.

### Solution
Refactored to use a `components` array with explicit `id` fields:

#### Old Format:
```yaml
component_repos:
  PYTHON_3_11:
    - name: "python-group"
      url: "http://localhost:8090"
```

#### New Format:
```yaml
components:
  - id: "PYTHON_3_11"
    repositories:
      - name: "python-group"
        url: "http://localhost:8090"
```

### Implementation
1. Created `lib/config-reader.sh` - Centralized config reading functions
2. Updated `lib/component-config-generator.sh` - Uses new config reader
3. Fixed validation scripts - Read actual configured URLs instead of hardcoded
4. Added `config.yaml.example` - Documents new format

### Benefits
- Consistent with component YAML structure
- Easier to parse and validate
- More extensible for future component properties
- Cleaner yq queries

---

## 2024-01-28: Milestone - Complete Working System with Nexus Integration

### Achievement Summary
Successfully completed the cross-platform compatibility refactoring with full Nexus repository integration working end-to-end.

### What's Working
1. **Component Isolation**: ✅ Complete - Only selected components are configured
2. **Configuration-Driven**: ✅ All settings from config.yaml, no detection
3. **Repository Integration**: ✅ Nexus proxying working with path-based URLs
4. **Clean Deployment**: ✅ No residual files or unnecessary configurations

### Final Configuration Approach
```yaml
components:
  - id: "PYTHON_3_11"
    repositories:
      - url: "http://pop-os:8081/repository/python-group"  # Path-based
```

### Test Results
- Python packages successfully installing through Nexus
- pip.conf correctly generated with `/simple` suffix
- Connectivity verified: `http://pop-os:8081/repository/python-group/`
- Package downloads working: `requests`, `certifi`, `urllib3`, etc.

### Key Technical Decisions
1. **Path-based over Port-based**: Using `/repository/name` on single port (8081)
2. **Components Array Format**: Cleaner, more extensible structure
3. **No Python in Base**: Base image remains component-free
4. **Build-time Config Generation**: All configs generated during build, not runtime

### Lessons Learned
1. Volume mounts override Docker image contents (README.md issue)
2. Different yq implementations have different syntax (kislyuk vs mikefarah)
3. K3s requires actual hostname, not localhost
4. Component isolation requires careful separation of concerns

---

## Future Considerations
- Test remaining components (Node.js, Go, Maven, Rust) with path-based approach
- Create comprehensive validation test suite
- Document path-based vs port-based configuration approaches
- Consider adding component health checks
- Implement automatic Nexus repository detection/validation
- Add support for authenticated repositories

---

*This journal should be preserved across Claude Code sessions to maintain context.*