# AI DevKit Pod Configurator - Comprehensive Test Plan

## Overview
This test plan provides comprehensive coverage across 17 sections with 35+ test cases covering:
- Core system architecture and principles
- Component management and isolation
- Security, network resilience, and resource constraints
- Build system, deployment, and operational scenarios
- Performance baselines and compatibility matrices

### Test Coverage Summary
- **Functional Test Sections**: 17 (Core, Repos, Components, Credentials, Build, Platform, Errors, Performance, Integration, Init Container, Dependencies, Security, Network, Resources, Compatibility, Operations)
- **Code Standards Section**: 1 (Optional static analysis checks)
- **Test Cases**: 35+ functional tests + 3 code standard validations
- **Coverage Areas**: Functional, Security, Performance, Resilience, Operations, Code Quality

### Key Testing Principles
- Pure bash template processing (no Python dependencies)
- YAML-based configuration system using yq v4
- Repository configuration with defaults and overrides
- Init container file distribution architecture
- Component isolation and dependency management

## Important Note on Component Selection
The build script uses an interactive UI for component selection. When the test steps mention specific components, you should:
1. Run `./build-and-deploy.sh`
2. Select the specified components from the interactive menu
3. Component names are lowercase with dashes (e.g., python-3.11, nodejs-20, go-1.22)
4. The runtime (k3s, docker, etc.) is determined from your config.yaml file

---

## Section 1: Core System Tests

### Test 1.1: YAML Configuration Processing
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

### Test 5.1: Clean Build with Multiple Compatible Components
**Objective:** System builds successfully with a large set of compatible components

**Setup:**
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Create config with minimal settings
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"
EOF

# Select these specific compatible components from the interactive UI:
# - Go 1.22
# - Java 21 (OpenJDK)  
# - Kotlin
# - Node.js 22.x
# - Python 3.11 (Official)
# - Ruby 3.3 (rbenv)
# - Rust (Stable Channel)
# - Scala 3
# - Maven (Java build tool)
# - Microsoft TUI Test

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
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Create config
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"
EOF

# Note: Incremental builds currently require manual component selection via TUI
# First build - select Python 3.11 in TUI
./build-and-deploy.sh

# Second build - select both Python 3.11 and Node.js 20 in TUI
./build-and-deploy.sh
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
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Test with K3s (primary test environment)
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"
EOF
./build-and-deploy.sh
# Select Python 3.11 in the interactive TUI

# Test with Docker
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "docker"
  runtime: "docker"
  runtime_import: "direct"
EOF
./build-and-deploy.sh
# Select Python 3.11 in the interactive TUI

# Test with Colima
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "docker"
  runtime: "colima"
  runtime_import: "kubectl"
EOF
./build-and-deploy.sh
# Select Python 3.11 in the interactive TUI
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
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Create config with invalid component
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

components:
  - id: "INVALID_COMPONENT"
EOF

# Try to build (should handle gracefully)
# Note: Non-interactive mode not yet implemented
# TODO: Implement config-driven component selection for CI/CD
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
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Create malformed config (missing URL in repository)
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

components:
  - id: "PYTHON_3_11"
    repositories:
      - name: "bad-repo"
        # Missing URL - should be handled gracefully
EOF

./build-and-deploy.sh
# Select Python 3.11 in the interactive TUI
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
```bash
# Create old format config with nexus section
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

nexus:
  enabled: true
  host: "nexus.example.com"
  username: "user"
  password: "pass"
EOF

# Note: Migration script has been removed as the old config format is obsolete
```

**Validation:**
```bash
# Check config
cat ~/.ai-devkit/config.yaml
# Expected: Config uses current format
```

---

## Section 9: Performance Tests

### Test 9.1: Large Component Set
**Objective:** System handles many components efficiently

**Setup:**
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Create config with basic settings
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"
EOF

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

**Setup:**
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Configure with Python repository
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

components:
  - id: "PYTHON_3_11"
    repositories:
      - name: "pypi"
        url: "https://pypi.org/simple"
EOF

# Build and deploy
./build-and-deploy.sh
# Select Python 3.11 in the interactive TUI
```

**Steps:**
1. Connect to container: `ssh devuser@localhost -p 2222`
2. Create Python project: `mkdir myproject && cd myproject`
3. Create virtual env: `python3.11 -m venv venv && source venv/bin/activate`
4. Install dependencies: `pip install requests pytest`
5. Run tests: `pytest`
6. Build project: `python setup.py build`

**Validation:**
All steps complete successfully with configured repositories

### Test 10.2: CI/CD Integration
**Objective:** System works in automated pipelines

**Setup:**
```bash
# Clean up any previous deployments
kubectl delete namespace ai-devkit --ignore-not-found=true

# Create config with component selection for non-interactive mode
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

components:
  - id: "PYTHON_3_11"
  - id: "NODEJS_20"
EOF

# Run in non-interactive mode (skip UI)
# Note: Non-interactive mode not yet implemented
# TODO: Implement config-driven component selection for CI/CD
./build-and-deploy.sh
```

**Validation:**
- No user prompts
- Exit codes correct
- Logs parseable

---

## Section 11: Init Container Architecture Tests

### Test 11.1: File Mapping Validation
**Objective:** Verify init container correctly processes file mappings

**Setup:**
```bash
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"
EOF
```

**Deploy:**
```bash
./build-and-deploy.sh
# Select Python 3.11 and Node.js 20
```

**Validation in Container:**
```bash
# Check that files were correctly placed
ls -la ~/.config/pip/pip.conf
ls -la ~/.npmrc
ls -la ~/.ai-devkit/tests/

# Verify file permissions
stat -c "%a %U" ~/.config/pip/pip.conf
# Expected: 644 devuser
```

### Test 11.2: Init Container Failure Handling
**Objective:** Verify graceful failure when init container can't write files

**Setup:**
```bash
# Intentionally create read-only volume mount
# Modify deployment to test failure scenarios
```

**Expected:** Pod should fail to start with clear error message in init container logs

---

## Section 12: Component Dependency Tests

### Test 12.1: Component Dependencies Resolution
**Objective:** Verify components with dependencies work correctly

**Deploy:**
```bash
./build-and-deploy.sh
# Select Maven (should auto-select Java as dependency)
```

**Validation:**
```bash
# Both Java and Maven should be installed
java -version
mvn -version
```

### Test 12.2: Conflicting Components
**Objective:** Verify mutually exclusive components are handled

**Deploy:**
```bash
./build-and-deploy.sh
# Try to select both Python 3.10 and Python 3.11
# UI should prevent this selection
```

---

## Section 13: Security Tests

### Test 13.1: Repository URL Input Validation
**Objective:** Verify malicious repository URLs are handled safely

**Setup:**
```bash
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

components:
  - id: "PYTHON_3_11"
    repositories:
      - name: "malicious-repo"
        url: "https://example.com/repo;rm -rf /"
      - name: "injection-test"
        url: "https://example.com/\$(whoami)"
EOF
```

**Deploy:**
```bash
./build-and-deploy.sh
# Select Python 3.11
```

**Expected:** URLs should be escaped/sanitized, no command execution

### Test 13.2: Credential File Permissions
**Objective:** Verify credential files have secure permissions

**Validation in Container:**
```bash
# Check all credential file permissions
find ~/.config -name "*.conf" -o -name "*.rc" | while read f; do
  stat -c "%a %n" "$f"
done
# Expected: 600 or 644, never 777 or world-writable

# Check git credentials
stat -c "%a" ~/.git-credentials 2>/dev/null
# Expected: 600 if exists
```

### Test 13.3: No Secrets in Logs
**Objective:** Verify sensitive data isn't logged

**Setup:**
```bash
# Set up with auth tokens
cat > ~/.ai-devkit/auth-tokens.yaml <<EOF
tokens:
  nexus_read:
    username: "testuser"
    password: "secret-password-12345"
EOF
```

**Deploy and Check:**
```bash
./build-and-deploy.sh > build.log 2>&1
# Select Python 3.11

# Check logs don't contain secrets
grep -i "secret-password-12345" build.log build-and-deploy.log
# Expected: No matches

grep -i "password" build.log build-and-deploy.log | grep -v "password:"
# Expected: No actual password values shown
```

---

## Section 14: Network Resilience Tests

### Test 14.1: DNS Resolution Failure
**Objective:** Handle DNS failures gracefully

**Setup:**
```bash
# Use non-resolvable hostname
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

components:
  - id: "PYTHON_3_11"
    repositories:
      - name: "unreachable"
        url: "https://non-existent-domain-12345.invalid/simple"
EOF
```

**Expected:** Build completes with warning, uses PyPI defaults

### Test 14.2: Network Timeout Handling
**Objective:** Verify timeout behavior for slow networks

**Setup:**
```bash
# Use a black hole IP that will timeout
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

components:
  - id: "NODEJS_20"
    repositories:
      - name: "slow-repo"
        url: "https://10.255.255.1/registry"
EOF
```

**Expected:** Reasonable timeout, clear error message

### Test 14.3: Certificate Validation
**Objective:** Handle self-signed certificates appropriately

**Setup:**
```bash
# Repository with self-signed cert
cat > ~/.ai-devkit/config.yaml <<EOF
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
  runtime: "k3s"
  runtime_import: "direct"

components:
  - id: "PYTHON_3_11"
    repositories:
      - name: "self-signed"
        url: "https://localhost:8443/simple"
        insecure: true  # If supported
EOF
```

**Expected:** Warning about insecure connection, but allows if configured

---

## Section 15: Resource Constraint Tests

### Test 15.1: Low Disk Space
**Objective:** Handle disk space exhaustion gracefully

**Pre-test:**
```bash
# Check available space
df -h /var/lib/docker or /var/lib/containerd
# Note: This is a destructive test - only run in test environment
```

**Setup:**
```bash
# Fill up disk to leave only 100MB free (TEST ENVIRONMENT ONLY)
# dd if=/dev/zero of=/tmp/largefile bs=1M count=$(($(df /tmp | tail -1 | awk '{print $4}')/1024 - 100))
```

**Expected:** Clear error message about insufficient disk space

### Test 15.2: Memory Pressure
**Objective:** Verify behavior under memory constraints

**Deploy with limits:**
```bash
# Modify deployment to add resource limits
# After deployment, check container limits:
kubectl describe pod -n ai-devkit | grep -A5 "Limits:"
```

**Validation:**
```bash
# Inside container, check memory
free -h
# Try memory-intensive operation
python3 -c "x = [0] * (10**9)"  # If Python installed
# Expected: OOM killer or graceful failure
```

### Test 15.3: Build Performance Baseline
**Objective:** Establish performance baselines

**Measurement:**
```bash
# Clean build timing
time ./build-and-deploy.sh
# Select: Python 3.11, Node.js 20, Go 1.22

# Record:
# - Total build time
# - Image size
# - Container startup time
# - Memory usage during build
```

**Baseline Expectations:**
- Build time: < 10 minutes for 3 components
- Image size: < 3GB for 3 languages
- Startup time: < 60 seconds
- Memory usage: < 2GB during build

---

## Section 16: Component Compatibility Matrix

### Test 16.1: Language Version Conflicts
**Objective:** Verify mutually exclusive components are handled

**Test Matrix:**
```bash
# These combinations should be prevented:
# - Python 3.10 + Python 3.11
# - Java 11 + Java 17 + Java 21
# - Node.js 20 + Node.js 22
# - Ruby System + Ruby 3.3
```

**Validation:** TUI should prevent selecting conflicting versions

### Test 16.2: Build Tool Dependencies
**Objective:** Verify build tools auto-select dependencies

**Test Cases:**
```bash
# Maven → Should auto-select Java
# Gradle → Should auto-select Java  
# SBT → Should auto-select Scala and Java
```

**Validation:** Dependencies automatically selected in TUI

### Test 16.3: Maximum Component Load
**Objective:** Test with all non-conflicting components

**Deploy:**
```bash
./build-and-deploy.sh
# Select one from each language group plus all tools
# Expected selection: ~15-20 components
```

**Validation:**
```bash
# All components functional
~/.ai-devkit/tests/run-all.sh
# Expected: All tests pass
```

---

## Section 17: Operational Tests

### Test 17.1: Container Restart Persistence
**Objective:** Verify configurations persist across restarts

**Setup:**
```bash
# Deploy with components
./build-and-deploy.sh
# Select Python 3.11, Node.js 20

# In container, create test files
echo "test" > ~/workspace/test.txt
echo "config" > ~/.config/test.conf
```

**Test:**
```bash
# Restart pod
kubectl delete pod -n ai-devkit ai-devkit-0
# Wait for restart
kubectl wait --for=condition=ready pod -n ai-devkit ai-devkit-0

# Verify files persist
kubectl exec -n ai-devkit ai-devkit-0 -- cat ~/workspace/test.txt
kubectl exec -n ai-devkit ai-devkit-0 -- cat ~/.config/test.conf
```

### Test 17.2: Log Aggregation
**Objective:** Verify all logs are accessible

**Validation:**
```bash
# Check init container logs
kubectl logs -n ai-devkit ai-devkit-0 -c init-copy-files

# Check main container logs  
kubectl logs -n ai-devkit ai-devkit-0 -c ai-devkit

# Check build logs
cat build-and-deploy.log | wc -l
# Expected: Comprehensive logging of all operations
```

### Test 17.3: Health Checks
**Objective:** Verify container health monitoring

**Validation:**
```bash
# Check pod status
kubectl get pod -n ai-devkit ai-devkit-0 -o json | jq .status.conditions

# SSH connectivity test
ssh -p 2222 devuser@localhost "echo 'SSH OK'"

# Component functionality
ssh -p 2222 devuser@localhost "python3 --version && node --version"
```

---

## Section 18: Code Standards Validation

*Note: These are code quality checks rather than functional tests. They validate architectural principles and coding standards. Consider implementing these as pre-commit hooks or CI/CD pipeline checks instead of manual tests.*

### Test 18.1: Python-Free Core System
**Objective:** Verify core system maintains zero Python dependencies per architectural principles

**Type:** Static Code Analysis

**Validation:**
```bash
# Check no Python in core scripts
grep -r "python3 -c\|import jinja2" lib/*.sh build-and-deploy.sh
# Expected: No matches

# Check no Python imports or execution
grep -r "^import \|from .* import" lib/*.sh
# Expected: No matches

# Check Dockerfile doesn't install Python in base image
grep -E "^RUN.*python" docker/Dockerfile.base
# Expected: No matches (except comments)

# Verify bash-only template processing
grep -r "jinja2\|django\|mako" lib/
# Expected: No template engine references

# Check that Dockerfile.base installs Go-based yq
grep "yq" docker/Dockerfile.base
# Expected: Shows installation of mikefarah/yq v4
```

**Rationale:** This validates Principle #3 from PRINCIPLES.md - "Pure Bash, Zero Python Dependencies"

### Test 18.2: Hardcoded Paths Validation
**Objective:** Verify no hardcoded /home/devuser paths (should use DEVUSER_HOME variable)

**Validation:**
```bash
# Check for hardcoded paths
grep -r "/home/devuser" lib/*.sh build-and-deploy.sh | grep -v "DEVUSER_HOME"
# Expected: No matches (all should use $DEVUSER_HOME or ${DEVUSER_HOME})
```

### Test 18.3: Component Isolation Validation
**Objective:** Verify core scripts contain no component-specific code

**Validation:**
```bash
# Check for package manager names in core
grep -E "pip|npm|maven|gradle|cargo|gem|go get" build-and-deploy.sh
# Expected: No matches in core script

# Check for language-specific commands
grep -E "python|node|java|ruby|rust" build-and-deploy.sh | grep -v "#"
# Expected: No direct language references
```

---

## Test Execution Checklist

- [ ] Section 1: Core System Tests
  - [ ] 1.1 YAML Processing
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
- [ ] Section 9: Performance
  - [ ] 9.1 Large Component Set
- [ ] Section 10: Integration
  - [ ] 10.1 End-to-End Workflow
  - [ ] 10.2 CI/CD Integration
- [ ] Section 11: Init Container Architecture
  - [ ] 11.1 File Mapping Validation
  - [ ] 11.2 Init Container Failure Handling
- [ ] Section 12: Component Dependencies
  - [ ] 12.1 Component Dependencies Resolution
  - [ ] 12.2 Conflicting Components
- [ ] Section 13: Security Tests
  - [ ] 13.1 Repository URL Input Validation
  - [ ] 13.2 Credential File Permissions
  - [ ] 13.3 No Secrets in Logs
- [ ] Section 14: Network Resilience
  - [ ] 14.1 DNS Resolution Failure
  - [ ] 14.2 Network Timeout Handling
  - [ ] 14.3 Certificate Validation
- [ ] Section 15: Resource Constraints
  - [ ] 15.1 Low Disk Space
  - [ ] 15.2 Memory Pressure
  - [ ] 15.3 Build Performance Baseline
- [ ] Section 16: Component Compatibility Matrix
  - [ ] 16.1 Language Version Conflicts
  - [ ] 16.2 Build Tool Dependencies
  - [ ] 16.3 Maximum Component Load
- [ ] Section 17: Operational Tests
  - [ ] 17.1 Container Restart Persistence
  - [ ] 17.2 Log Aggregation
  - [ ] 17.3 Health Checks
- [ ] Section 18: Code Standards Validation (Optional)
  - [ ] 18.1 Python-Free Core System
  - [ ] 18.2 Hardcoded Paths Validation
  - [ ] 18.3 Component Isolation Validation

---

## Notes

- Run tests in order for best results
- Some tests require external services (Nexus, etc.)
- Document any failures with logs and configuration
- Each test should be independently reproducible
- Section 18 (Code Standards) should ideally be automated as pre-commit hooks or CI/CD checks

## Automation Recommendations

### Code Standards Checks (Section 18)
Consider implementing these as:
1. **Pre-commit hooks** using tools like:
   - `pre-commit` framework with custom scripts
   - Shell script checks in `.git/hooks/pre-commit`
2. **CI/CD Pipeline checks** in GitHub Actions:
   ```yaml
   - name: Validate No Python Dependencies
     run: |
       ! grep -r "python3 -c\|import jinja2" lib/*.sh
       ! grep -E "^RUN.*python" docker/Dockerfile.base
   ```
3. **Makefile targets** for local validation:
   ```bash
   make validate-standards
   ```

*Last Updated: 2025-01-10 - Reorganized with code standards as separate section, expanded to 18 sections total*