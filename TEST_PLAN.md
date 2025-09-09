# AI DevKit Pod Configurator - Comprehensive Test Plan

## Overview
This test plan covers the complete system after major architectural refactoring:
- Separation of concerns with component-owned configuration
- Pure bash template processing (no Python dependencies)
- YAML-based configuration system using yq v4
- Repository configuration with defaults and overrides

## Important Note on Component Selection
The build script uses an interactive UI for component selection. When the test steps mention specific components, you should:
1. Run `./build-and-deploy.sh`
2. Select the specified components from the interactive menu
3. Component names are lowercase with dashes (e.g., python-3.11, nodejs-20, go-1.22)
4. The runtime (k3s, docker, etc.) is determined from your config.yaml file

---

## Section 1: Core System Tests

### Test 1.1: Python-Free Core System
**Objective:** Verify core system has no Python dependencies

**Setup:**
```bash
# Fresh checkout, no components selected
rm -rf ~/.ai-devkit
mkdir -p ~/.ai-devkit
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"
EOF
```

**Validation:**
```bash
# Check no Python in core scripts
grep -r "python3 -c\|import jinja2" lib/*.sh
# Expected: No matches

# Check Dockerfile doesn't install Python
grep -E "^RUN.*python" docker/Dockerfile.base
# Expected: No matches (except comments)

# Check that Dockerfile.base installs Go-based yq
grep "yq" docker/Dockerfile.base
# Expected: Shows installation of mikefarah/yq v4

# Note: To verify yq in the actual image, build first:
# ./build-and-deploy.sh
# Then after build completes:
# sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io run --rm ai-devkit:latest /usr/local/bin/yq --version
# Expected: yq (https://github.com/mikefarah/yq/) version v4.x.x
```

### Test 1.2: YAML Configuration Processing
**Objective:** Verify YAML-based template processor works

**Components to Deploy:** N/A (Unit test - no deployment)

**Setup:**
```bash
# Source the template processor
source lib/template-processor-bash.sh

# Create test YAML data
yaml_data='repositories:
  - name: test-repo
    url: https://example.com/repo
    access: read_only
component_id: TEST_COMPONENT
format: pypi'
```

**Validation:**
```bash
# Generate configuration
process_template_bash "/dev/null" "$yaml_data" "/tmp/test.conf"
cat /tmp/test.conf
# Expected: Valid pip.conf with test-repo URL
```

---

## Section 2: Repository Configuration Tests

**Note:** Each test requires creating a new config.yaml file. The setup commands show exactly how to create the file with the required configuration.

### Test 2.1: Default Repositories (No User Config)
**Objective:** Components use their default repositories when no user config exists

**Setup:**
```bash
# Create config with no components section
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"
EOF
```

**Deploy:**
```bash
# Select python-3.11 and nodejs-20 from the interactive UI
./build-and-deploy.sh
```

**Validation in Container:**
```bash
# Python default
cat ~/.config/pip/pip.conf
# Expected:
# [global]
# index-url = https://pypi.org/simple

# Node.js default
cat ~/.npmrc
# Expected:
# registry=https://registry.npmjs.org/

# Test connectivity
pip download --no-deps requests
npm view express version
```

### Test 2.2: Complete Override (include_default_repos: false)
**Objective:** User repositories completely replace defaults

**Components to Deploy:** Python 3.11 (Official)

**Setup:**
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Create config with custom repository overriding defaults
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

credentials:
  - id: "nexus-admin"
    username: "admin"
    password: "admin123"

components:
  - id: "PYTHON_3_11"
    include_default_repos: false
    repositories:
      - name: "nexus-pypi"
        url: "http://nexus:8081/repository/pypi-proxy/simple"
        access: "read_only"
        auth: "nexus-admin"
EOF
```

**Deploy:**
```bash
# Select ONLY "Python 3.11 (Official)" from the interactive UI
./build-and-deploy.sh
```

**Validation in Container:**
```bash
cat ~/.config/pip/pip.conf
# Expected: Only nexus URL, no pypi.org
# [global]
# index-url = http://nexus:8081/repository/pypi-proxy/simple
# trusted-host = nexus
```

### Test 2.3: Merge with Defaults (include_default_repos: true)
**Objective:** User repos are primary, defaults are fallback

**Components to Deploy:** Python 3.11 (Official)

**Setup:**
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Create config that merges with defaults
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

components:
  - id: "PYTHON_3_11"
    include_default_repos: true
    repositories:
      - name: "private-pypi"
        url: "https://private.example.com/simple"
        access: "read_write"
EOF
```

**Deploy:**
```bash
# Select ONLY "Python 3.11 (Official)" from the interactive UI
./build-and-deploy.sh
```

**Validation in Container:**
```bash
cat ~/.config/pip/pip.conf
# Expected:
# [global]
# index-url = https://private.example.com/simple
# extra-index-url =
#     https://pypi.org/simple
```

### Test 2.4: Multi-Component Configuration
**Objective:** Multiple components with different repository configs

**Components to Deploy:** 
- Python 3.11 (Official)
- Node.js 20.x LTS
- Go 1.22

**Setup:**
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Create config with multiple components
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

components:
  - id: "PYTHON_3_11"
    include_default_repos: false
    repositories:
      - name: "nexus-pypi"
        url: "http://nexus:8081/repository/pypi/simple"
  
  - id: "NODEJS_20"
    include_default_repos: true
    repositories:
      - name: "nexus-npm"
        url: "http://nexus:8081/repository/npm/"
  
  - id: "GO_1_22"
    # Uses only defaults (no user config)
EOF
```

**Deploy:**
```bash
# Select ALL THREE components from the interactive UI:
# - "Python 3.11 (Official)"
# - "Node.js 20.x LTS" 
# - "Go 1.22"
./build-and-deploy.sh
```

**Validation in Container:**
```bash
# Python - nexus only
cat ~/.config/pip/pip.conf
# No pypi.org

# Node.js - nexus primary, npmjs fallback
cat ~/.npmrc
# registry=http://nexus:8081/repository/npm/

# Go - defaults only
source ~/.config/go/go-env.sh
echo $GOPROXY
# https://proxy.golang.org,direct
```

---

## Section 3: Component Isolation Tests

### Test 3.1: Component-Specific Configuration
**Objective:** Only selected components have configurations in container

**Components to Deploy:** Python 3.11 (Official) ONLY

**Setup:**
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Use minimal config (no custom repositories)
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"
EOF
```

**Deploy:**
```bash
# Select ONLY "Python 3.11 (Official)" from the interactive UI
./build-and-deploy.sh
```

**Validation in Container:**
```bash
# Python config exists
ls ~/.config/pip/pip.conf
# Expected: File exists

# Node.js config doesn't exist
ls ~/.npmrc
# Expected: No such file

# Maven config doesn't exist
ls ~/.m2/settings.xml
# Expected: No such file
```

### Test 3.2: Component Test Injection
**Objective:** Component tests are executable in container

**Components to Deploy:** 
- Python 3.11 (Official)
- Node.js 20.x LTS

**Setup:**
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Use minimal config
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"
EOF
```

**Deploy:**
```bash
# Select BOTH components from the interactive UI:
# - "Python 3.11 (Official)"
# - "Node.js 20.x LTS"
./build-and-deploy.sh
```

**Validation in Container:**
```bash
# Run all tests
~/.ai-devkit/tests/run-all.sh
# Expected: All component tests pass

# List available test scripts
ls ~/.ai-devkit/tests/
# Expected output should show files like:
# python-3-11-verify.sh
# python-3-11-test-version.sh
# python-3-11-test-pip.sh
# python-3-11-test-installation.sh
# python-3-11-test-functionality.sh
# nodejs-20-verify.sh
# nodejs-20-test-version.sh
# nodejs-20-test-npm.sh
# nodejs-20-test-installation.sh
# nodejs-20-test-functionality.sh
# run-all.sh

# Run specific component test (example)
~/.ai-devkit/tests/python-3-11-verify.sh
# Expected: SUCCESS

~/.ai-devkit/tests/nodejs-20-verify.sh
# Expected: SUCCESS
```

---

## Section 4: Credential Management Tests

### Test 4.1: Authenticated Repository Access
**Objective:** Credentials are properly applied to repositories

**Components to Deploy:** Node.js 20.x LTS

**Setup:**
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Create config with authenticated repository
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

credentials:
  - id: "registry-auth"
    username: "user"
    password: "pass123"

components:
  - id: "NODEJS_20"
    repositories:
      - name: "private-npm"
        url: "https://registry.private.com"
        auth: "registry-auth"
EOF
```

**Deploy:**
```bash
# Select ONLY "Node.js 20.x LTS" from the interactive UI
./build-and-deploy.sh
```

**Validation in Container:**
```bash
# Check .npmrc has auth token
cat ~/.npmrc
# Expected: Contains auth configuration
```

### Test 4.2: Missing Credential Reference
**Objective:** System warns about missing credentials

**Setup:**
```bash
# Create config with missing credential reference
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

components:
  - id: "PYTHON_3_11"
    repositories:
      - name: "private"
        url: "https://private.com/simple"
        auth: "non-existent-id"
EOF
```

**Deploy & Validation:**
```bash
# Run build-and-deploy.sh interactively
./build-and-deploy.sh
# Select python-3.11 from the TUI menu when prompted
# Complete the build process

# After build completes, check the log file for warnings
grep -i warning build-and-deploy.log
# Expected: Warning about missing credential 'non-existent-id'
```

---

## Section 5: Build System Tests

### Test 5.1: Clean Build with All Components
**Objective:** System builds successfully with all components

**Setup:**
```bash
# Select ALL components from the interactive UI
./build-and-deploy.sh
```

**Validation:**
```bash
# Check deployment completes
kubectl get pods -n ai-devkit
# Expected: Pod running

# Verify all language tools available
kubectl exec -n ai-devkit $POD -- python3.11 --version
kubectl exec -n ai-devkit $POD -- node --version
kubectl exec -n ai-devkit $POD -- go version
kubectl exec -n ai-devkit $POD -- java -version
kubectl exec -n ai-devkit $POD -- rustc --version
```

### Test 5.2: Incremental Build
**Objective:** Cached builds work correctly

**Setup:**
```bash
# First build
./build-and-deploy.sh --components "PYTHON_3_11"

# Second build with additional component
./build-and-deploy.sh --components "PYTHON_3_11,NODEJS_20"
```

**Validation:**
```bash
# Check build uses cache
# Build time should be significantly faster
# Both components should be available
```

---

## Section 6: Cross-Platform Tests

### Test 6.1: Different Container Runtimes
**Objective:** System works with k3s, docker, colima, minikube

**Setups:**
```yaml
# K3s (primary test environment)
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"

# Docker
container:
  build_command: "docker"
  runtime: "docker"

# Colima
container:
  build_command: "docker"
  runtime: "colima"
```

**Validation:**
Each runtime should successfully:
- Build the image
- Deploy the pod
- Generate correct configurations
- Pass component tests

---

## Section 7: Error Handling Tests

### Test 7.1: Invalid Component ID
**Objective:** System handles invalid component gracefully

**Setup:**
```bash
# Try to select an invalid component (manual test)
./build-and-deploy.sh
```

**Validation:**
```bash
# Expected: Error message about invalid component
# Build should fail gracefully
```

### Test 7.2: Malformed Configuration
**Objective:** System detects and reports config errors

**Setup:**
```yaml
components:
  - id: "PYTHON_3_11"
    repositories:
      - name: "bad-repo"
        # Missing URL
```

**Validation:**
```bash
# Expected: Warning or error about missing URL
# System should use defaults or fail gracefully
```

---

## Section 8: Migration Tests

### Test 8.1: Legacy Configuration Migration
**Objective:** Old configs are properly migrated

**Setup:**
```yaml
# Old format with nexus section
nexus:
  enabled: true
  host: "nexus.example.com"
```

**Validation:**
```bash
./scripts/migrate-config.sh
# Expected: Config converted to new format
```

---

## Section 9: Performance Tests

### Test 9.1: Large Component Set
**Objective:** System handles many components efficiently

**Setup:**
```bash
# Select 10+ components from the interactive UI:
# python-3.11, nodejs-20, go-1.22, java-17-openjdk, rust-stable,
# ruby-3.3, scala-3, kotlin, maven, gradle
./build-and-deploy.sh
```

**Validation:**
- Build completes in reasonable time
- All configurations generated correctly
- Container starts successfully
- Memory usage acceptable

---

## Section 10: Integration Tests

### Test 10.1: End-to-End Development Workflow
**Objective:** Complete development cycle works

**Steps:**
1. Configure repositories
2. Build and deploy
3. Connect to container
4. Create Python project
5. Install dependencies
6. Run tests
7. Build project

**Validation:**
All steps complete successfully with configured repositories

### Test 10.2: CI/CD Integration
**Objective:** System works in automated pipelines

**Setup:**
```bash
# Note: Non-interactive mode may need pre-selection or config file
# This test may need adjustment based on implementation
./build-and-deploy.sh --no-select
```

**Validation:**
- No user prompts
- Exit codes correct
- Logs parseable

---

## Test Execution Checklist

- [ ] Section 1: Core System Tests
  - [ ] 1.1 Python-Free Core
  - [ ] 1.2 YAML Processing
- [ ] Section 2: Repository Configuration
  - [ ] 2.1 Default Repositories
  - [ ] 2.2 Complete Override
  - [ ] 2.3 Merge with Defaults
  - [ ] 2.4 Multi-Component
- [ ] Section 3: Component Isolation
  - [ ] 3.1 Component-Specific Config
  - [ ] 3.2 Test Injection
- [ ] Section 4: Credential Management
  - [ ] 4.1 Authenticated Access
  - [ ] 4.2 Missing Credentials
- [ ] Section 5: Build System
  - [ ] 5.1 Clean Build
  - [ ] 5.2 Incremental Build
- [ ] Section 6: Cross-Platform
  - [ ] 6.1 Different Runtimes
- [ ] Section 7: Error Handling
  - [ ] 7.1 Invalid Component
  - [ ] 7.2 Malformed Config
- [ ] Section 8: Migration
  - [ ] 8.1 Legacy Migration
- [ ] Section 9: Performance
  - [ ] 9.1 Large Component Set
- [ ] Section 10: Integration
  - [ ] 10.1 End-to-End Workflow
  - [ ] 10.2 CI/CD Integration

---

## Notes

- Run tests in order for best results
- Some tests require external services (Nexus, etc.)
- Document any failures with logs and configuration
- Each test should be independently reproducible

*Last Updated: 2024-11-29 - Post-refactor with YAML support*