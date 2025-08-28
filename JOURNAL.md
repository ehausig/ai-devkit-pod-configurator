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

## Future Considerations
- Separate Nexus APT proxy from language package proxies
- May need to reintroduce `configure-ai-devkit.sh` for initial setup
- Consider config schema validation
- Document all required config fields
- Add validation for additional package managers (Maven, Gradle, etc.)
- Implement automatic host address discovery for different runtimes

---

*This journal should be preserved across Claude Code sessions to maintain context.*