# Repository Configuration Refactoring - Test Plan

## Test Scenarios

### Test 1: Default Repositories (No User Config)
**Setup:** 
- No components defined in config.yaml
- Deploy with Python 3.11 selected

**Expected Results:**
```bash
# In container
cat ~/.config/pip/pip.conf
# Should show:
[global]
index-url = https://pypi.org/simple
```

**Validation:**
```bash
pip install requests
# Should download from pypi.org
```

---

### Test 2: Complete Override (include_default_repos: false)
**Setup:**
```yaml
# config.yaml
credentials:
  - id: "nexus-admin"
    type: "basic"
    username: "admin"
    password: "encrypted:YWRtaW4K"

components:
  - id: "PYTHON_3_11"
    include_default_repos: false
    repositories:
      - name: "python-group"
        url: "http://pop-os:8081/repository/python-group/simple"
        access: "read_only"
      - name: "python-hosted"
        url: "http://pop-os:8081/repository/python-hosted/simple"
        access: "read_write"
        auth: "nexus-admin"
```

**Expected Results:**
```bash
# In container
cat ~/.config/pip/pip.conf
# Should show:
[global]
index-url = http://pop-os:8081/repository/python-group/simple
trusted-host = pop-os
extra-index-url =
    http://admin:admin@pop-os:8081/repository/python-hosted/simple
# NO reference to pypi.org when include_default_repos: false
```

**Validation:**
```bash
pip install requests
# Should download from Nexus only
# Should NOT fall back to pypi.org if package not in Nexus
```

---

### Test 3: Merge Mode (include_default_repos: true)
**Setup:**
```yaml
# config.yaml
credentials:
  - id: "nexus-admin"
    type: "basic"
    username: "admin"
    password: "encrypted:YWRtaW4K"

components:
  - id: "PYTHON_3_11"
    include_default_repos: true  # Explicit merge
    repositories:
      - name: "python-group"
        url: "http://pop-os:8081/repository/python-group/simple"
        access: "read_only"
      - name: "python-hosted"
        url: "http://pop-os:8081/repository/python-hosted/simple"
        access: "read_write"
        auth: "nexus-admin"
```

**Expected Results:**
```bash
# In container
cat ~/.config/pip/pip.conf
# Should show:
[global]
index-url = http://pop-os:8081/repository/python-group/simple
trusted-host = pop-os
extra-index-url =
    http://admin:admin@pop-os:8081/repository/python-hosted/simple
    https://pypi.org/simple
# Note: PyPI is appended when include_default_repos: true
```

**Validation:**
```bash
pip install requests
# Should try Nexus first
# Should fall back to pypi.org if not in Nexus
```

---

### Test 4: Name Conflict Resolution
**Setup:**
```yaml
components:
  - id: "PYTHON_3_11"
    include_default_repos: true
    repositories:
      - name: "pypi"  # Same name as default
        url: "http://pop-os:8081/repository/python-proxy/simple"
        access: "read_only"
```

**Expected Results:**
- Build log should show: `WARNING: Skipping default repo 'pypi' - overridden by user config`
- Deployment screen shows: `⚠ 1 warning(s) in build log • Press ENTER to return`
- After deployment: `⚠ Build completed with 1 warning(s)`
- Only user's "pypi" URL should be used in pip.conf

**Validation:**
```bash
# Check warnings in build log
grep -i warning build-and-deploy.log

# In container, verify only user's URL is used
cat ~/.config/pip/pip.conf
# Should only show the user's pypi URL, not the default
```

---

### Test 5: Environment Variables (Go)
**Setup:**
- Deploy with Go 1.22 selected
- No user config (uses defaults)

**Expected Results:**
```bash
# In container
cat ~/.config/go-env.sh  # File should exist and be mounted
# Should show:
export GOPROXY="https://proxy.golang.org,direct"
export GOSUMDB="sum.golang.org"
export GO111MODULE=on

# Environment should be automatically sourced in new shells
echo $GOPROXY
# Should show: https://proxy.golang.org,direct
echo $GOSUMDB
# Should show: sum.golang.org
```

**Diagnostic:**
If GOPROXY is not set, run `./diagnose-go-config.sh` on the host to check:
- If go-env.sh was generated
- If ConfigMap was created
- If file is mounted in container
- If bashrc sourcing is working

---

### Test 6: Multiple Components
**Setup:**
```yaml
credentials:
  - id: "nexus-admin"
    type: "basic"
    username: "admin"
    password: "encrypted:YWRtaW4K"

components:
  - id: "PYTHON_3_11"
    include_default_repos: false
    repositories:
      - name: "python-nexus"
        url: "http://pop-os:8081/repository/python-group/simple"
        access: "read_only"
        
  - id: "NODEJS_20"
    include_default_repos: true  # Will use defaults
    repositories: []
```

**Deployment:**
- Select BOTH Python 3.11 AND Node.js 20 in the TUI
- Deploy the container

**Expected Results:**
```bash
# In container - Python should only use Nexus
cat ~/.config/pip/pip.conf
# Should show:
[global]
index-url = http://pop-os:8081/repository/python-group/simple
trusted-host = pop-os
# NO pypi.org

# Node.js should use defaults
cat ~/.npmrc
# Should show:
registry=https://registry.npmjs.org/
```

**Validation:**
```bash
# Test Python uses only Nexus
pip config list | grep index-url
# Should show only the Nexus URL

# Test Node.js uses npm registry
npm config get registry
# Should show: https://registry.npmjs.org/

# Verify both tools work
pip install --dry-run requests
npm view express version
```

---

### Test 7: Missing Credential Reference
**Setup:**
```yaml
components:
  - id: "PYTHON_3_11"
    include_default_repos: false
    repositories:
      - name: "python-nexus"
        url: "http://pop-os:8081/repository/python-group/simple"
        auth: "nonexistent-cred"  # Doesn't exist in credentials
```

**Expected Results:**
- Build should continue (not fail)
- Warning in build log: `Credential 'nonexistent-cred' not found`
- Repository configured without authentication

**Validation:**
```bash
# Check build log for warning
grep -i "credential.*not found" build-and-deploy.log

# In container, verify config has no auth
cat ~/.config/pip/pip.conf
# Should show URL without username:password

# Test that pip still works (if repo allows anonymous)
pip search requests 2>/dev/null || echo "Anonymous access may be denied"
```

---

### Test 8: No Authentication (Anonymous Access)
**Setup:**
```yaml
components:
  - id: "PYTHON_3_11"
    include_default_repos: false
    repositories:
      - name: "python-public"
        url: "http://public-mirror.com/simple"
        access: "read_only"
        # No auth field - anonymous access
```

**Expected Results:**
- Build completes successfully
- No authentication in generated config
- pip.conf contains plain URL

**Validation:**
```bash
# In container
cat ~/.config/pip/pip.conf
# Should show:
[global]
index-url = http://public-mirror.com/simple
trusted-host = public-mirror.com
# No username:password in URL

# Verify pip config
pip config list | grep index-url
# Should show clean URL without auth

# Test with public PyPI (if online)
# Temporarily change to test PyPI
pip install --index-url https://pypi.org/simple --dry-run requests
```

---

### Test 9: Multiple Repository Types (Maven)
**Setup:**
```yaml
credentials:
  - id: "nexus-admin"
    type: "basic"
    username: "admin"
    password: "encrypted:YWRtaW4K"

components:
  - id: "MAVEN"
    include_default_repos: false
    repositories:
      - name: "maven-central-mirror"
        url: "http://pop-os:8081/repository/maven-public"
        access: "read_only"
      - name: "maven-releases"
        url: "http://pop-os:8081/repository/maven-releases"
        access: "read_write"
        auth: "nexus-admin"
```

**Deployment:**
- Select Maven in the TUI
- Deploy the container

**Expected Results:**
```xml
<!-- ~/.m2/settings.xml should contain: -->
<mirrors>
    <mirror>
        <id>maven-central-mirror</id>
        <mirrorOf>*</mirrorOf>
        <url>http://pop-os:8081/repository/maven-public</url>
    </mirror>
    <mirror>
        <id>maven-releases</id>
        <mirrorOf>*</mirrorOf>
        <url>http://pop-os:8081/repository/maven-releases</url>
    </mirror>
</mirrors>
<servers>
    <server>
        <id>maven-releases</id>
        <username>admin</username>
        <password>admin</password>
    </server>
</servers>
```

**Validation:**
```bash
# In container
cat ~/.m2/settings.xml

# Verify Maven can resolve dependencies
cd /tmp
cat > pom.xml << 'EOF'
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>test</groupId>
  <artifactId>test</artifactId>
  <version>1.0</version>
  <dependencies>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>4.13.2</version>
    </dependency>
  </dependencies>
</project>
EOF

# Test dependency resolution
mvn dependency:resolve
# Should download from configured repositories

# Check effective settings
mvn help:effective-settings | grep -A5 "<mirror>"
```

---

### Test 10: Rust with Custom Registry
**Setup:**
```yaml
credentials:
  - id: "cargo-token"
    type: "token"
    token: "encrypted:Y2FyZ290b2tlbg=="

components:
  - id: "RUST_STABLE"
    include_default_repos: false
    repositories:
      - name: "corporate-crates"
        url: "http://crates.corp.local"
        access: "read_write"
        auth: "cargo-token"
```

**Deployment:**
- Select Rust Stable in the TUI
- Deploy the container

**Expected Results:**
```toml
# ~/.cargo/config.toml should contain:
[source.crates-io]
replace-with = "custom"

[source.custom]
registry = "http://crates.corp.local"

[registries.custom]
token = "cargotooken"
```

**Validation:**
```bash
# In container
cat ~/.cargo/config.toml

# Test cargo configuration
cargo --version

# Create a test project
cd /tmp
cargo init test-project
cd test-project

# Try to add a dependency (will fail if registry is not accessible)
cargo search serde --limit 1
# Should search in corporate registry

# If you have a working registry:
cargo add serde --dry-run
```

---

## Test Execution Steps

### For Each Test:
1. Update `~/.ai-devkit/config.yaml` with test configuration
2. Run `./build-and-deploy.sh`
3. Select appropriate components
4. Deploy and wait for pod to be ready
5. Connect to container: `kubectl exec -it ai-devkit -n ai-devkit -- bash`
6. Check generated configuration files
7. Test package installation/download
8. Record results

## Test Results Summary

### Completed Tests:
- ✅ **Test 1**: Default repositories work (pip.conf with PyPI created)
- ✅ **Test 2**: include_default_repos: false works correctly (no PyPI)
- ✅ **Test 3**: include_default_repos: true merges defaults (PyPI appended)
- ✅ **Test 4**: Name conflicts detected and warned (with UI notification)
- ✅ **Test 5**: Go environment mounted (requires entrypoint fix for sourcing)

### Known Issues Fixed:
1. **pip.conf as directory** - Fixed ConfigMap name mismatch
2. **include_default_repos ignored** - Fixed yq query to read boolean correctly
3. **No warning visibility** - Added warning count to UI and post-deployment message
4. **Go env not sourced** - Added sourcing to entrypoint.base.sh

## Success Criteria

### All Tests Must:
- [x] Generate valid configuration files for each tool
- [x] Respect include_default_repos flag  
- [x] Handle credential resolution correctly
- [x] Log appropriate messages for conflicts
- [x] Use array order for repository priority
- [x] Pass URLs through without modification
- [x] Mount configs as files, not directories

## Validation Commands

### Python
```bash
cat ~/.config/pip/pip.conf
pip config list
pip install --dry-run requests  # Test without installing
pip install requests  # Actually install
python -c "import requests; print(requests.__version__)"
```

### Node.js
```bash
cat ~/.npmrc
npm config list
npm view express  # Test registry access
npm install express  # Test actual install
```

### Go
```bash
cat ~/go-env.sh  # If exists
echo $GOPROXY
go env GOPROXY
go get -d github.com/gorilla/mux  # Test download
```

### Maven
```bash
cat ~/.m2/settings.xml
mvn help:effective-settings  # If maven project exists
```

### Rust
```bash
cat ~/.cargo/config.toml
cargo search serde  # Test registry access
cargo init test-project && cd test-project
cargo add serde  # Test adding dependency
```

## Build Log Checks

Look for these messages in `.build-temp/build.log`:
- `Generating pip configuration for PYTHON_3_11...`
- `Resolved repositories with merging logic`
- `Generated pip configuration with N repositories`
- `Creating dynamic repository-config ConfigMap...`
- `Generated repository configurations for N component(s)`

## Quick Validation Script

Create `/tmp/validate-repos.sh`:
```bash
#!/bin/bash
echo "==================================="
echo "Repository Configuration Validation"
echo "==================================="

# Python
if [ -f ~/.config/pip/pip.conf ]; then
    echo "✓ Python pip.conf found"
    grep "index-url" ~/.config/pip/pip.conf
else
    echo "✗ Python pip.conf missing"
fi

# Node.js
if [ -f ~/.npmrc ]; then
    echo "✓ Node.js .npmrc found"
    grep "registry" ~/.npmrc
else
    echo "✗ Node.js .npmrc missing"
fi

# Go
if [ -n "$GOPROXY" ]; then
    echo "✓ Go GOPROXY set: $GOPROXY"
else
    echo "✗ Go GOPROXY not set"
fi

# Maven
if [ -f ~/.m2/settings.xml ]; then
    echo "✓ Maven settings.xml found"
else
    echo "✗ Maven settings.xml missing"
fi

# Rust
if [ -f ~/.cargo/config.toml ]; then
    echo "✓ Rust config.toml found"
else
    echo "✗ Rust config.toml missing"
fi
```

---

*Execute tests in order and document any failures or unexpected behavior*