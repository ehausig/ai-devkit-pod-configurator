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
    username: "admin"
    password: "encrypted:YWRtaW4K"

components:
  - id: "PYTHON_3_11"
    include_default_repos: false
    repositories:
      - name: "python-nexus"
        url: "http://pop-os:8081/repository/python-group/simple"
        access: "read_only"
        auth: "nexus-admin"
```

**Expected Results:**
```bash
# In container
cat ~/.config/pip/pip.conf
# Should show ONLY:
[global]
index-url = http://pop-os:8081/repository/python-group/simple
trusted-host = pop-os
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
    username: "admin"
    password: "encrypted:YWRtaW4K"

components:
  - id: "PYTHON_3_11"
    include_default_repos: true  # or omit (default is true)
    repositories:
      - name: "python-nexus"
        url: "http://pop-os:8081/repository/python-group/simple"
        access: "read_only"
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
        auth: "nexus-admin"
```

**Expected Results:**
- Build log should show: `WARNING: Skipping default repo 'pypi' - overridden by user config`
- Only user's "pypi" URL should be used

---

### Test 5: Environment Variables (Go)
**Setup:**
- Deploy with Go 1.22 selected
- Check for GOPROXY environment variable

**Expected Results:**
```bash
# In container
echo $GOPROXY
# Should show default or user-configured proxy
```

---

### Test 6: Multiple Components
**Setup:**
```yaml
components:
  - id: "PYTHON_3_11"
    include_default_repos: false
    repositories:
      - name: "python-nexus"
        url: "http://pop-os:8081/repository/python-group/simple"
        access: "read_only"
        auth: "nexus-admin"
        
  - id: "NODEJS_20"
    # No config - should use defaults
```

**Expected Results:**
- Python: Only Nexus repository
- Node.js: Default npm registry (https://registry.npmjs.org/)

---

### Test 7: Invalid Credential Reference
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
- Build should fail with clear error message
- Error should indicate missing credential ID

---

### Test 8: No Authentication
**Setup:**
```yaml
components:
  - id: "PYTHON_3_11"
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
- [ ] Generate valid configuration files for each tool
- [ ] Respect include_default_repos flag
- [ ] Handle credential resolution correctly
- [ ] Log warnings for name conflicts
- [ ] Use array order for repository priority
- [ ] Pass URLs through without modification

## Validation Commands

### Python
```bash
cat ~/.config/pip/pip.conf
pip config list
pip install --dry-run requests  # Test without installing
```

### Node.js
```bash
cat ~/.npmrc
npm config list
npm view express  # Test registry access
```

### Go
```bash
echo $GOPROXY
go env GOPROXY
```

### Maven
```bash
cat ~/.m2/settings.xml
mvn help:effective-settings
```

### Rust
```bash
cat ~/.cargo/config.toml
cargo search serde  # Test registry access
```

## Build Log Checks

Look for these messages in `.build-temp/build.log`:
- `Loading default repositories for PYTHON_3_11`
- `WARNING: Skipping default repo 'pypi' - overridden by user config`
- `Applying user repositories for PYTHON_3_11`
- `Generated pip configuration with N repositories`

---

*Execute tests in order and document any failures or unexpected behavior*