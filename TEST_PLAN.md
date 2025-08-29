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
# NO reference to pypi.org
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
      - name: "python-nexus"
        url: "http://pop-os:8081/repository/python-group/simple"
        access: "read_only"
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
    https://pypi.org/simple
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
- Build log should show: `Skipping default repo 'pypi' - already defined by user`
- Only user's "pypi" URL should be used

---

### Test 5: Environment Variables (Go)
**Setup:**
- Deploy with Go 1.22 selected
- No user config (uses defaults)

**Expected Results:**
```bash
# In container
cat ~/go-env.sh  # Check if env file was generated
source ~/go-env.sh
echo $GOPROXY
# Should show: https://proxy.golang.org,direct
echo $GOSUMDB
# Should show: sum.golang.org
```

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

**Expected Results:**
- Python: Only Nexus repository
- Node.js: Default npm registry (https://registry.npmjs.org/)

---

### Test 7: Missing Credential Reference
**Setup:**
```yaml
components:
  - id: "PYTHON_3_11"
    repositories:
      - name: "python-nexus"
        url: "http://pop-os:8081/repository/python-group/simple"
        auth: "nonexistent-cred"  # Doesn't exist in credentials
```

**Expected Results:**
- Build should continue with warning in log
- Repository configured without authentication
- Warning message: `Credential 'nonexistent-cred' not found`

---

### Test 8: No Authentication
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
- Should work without authentication
- No credentials in generated config

---

### Test 9: Multiple Repository Types
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