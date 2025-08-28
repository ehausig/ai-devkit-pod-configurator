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

## Future Considerations
- Separate Nexus APT proxy from language package proxies
- May need to reintroduce `configure-ai-devkit.sh` for initial setup
- Consider config schema validation
- Document all required config fields
- Add validation for additional package managers (Maven, Gradle, etc.)

---

*This journal should be preserved across Claude Code sessions to maintain context.*