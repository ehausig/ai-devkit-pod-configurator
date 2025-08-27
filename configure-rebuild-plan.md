# Configure AI DevKit Rebuild Plan

## Current Problems
1. **Overly verbose** - Too much text, too many prompts
2. **Duplicate Nexus prompts** - Asked twice for same info  
3. **Poor TUI** - Doesn't match build-and-deploy.sh quality
4. **Broken dual-panel** - Components show corrupted, exits unexpectedly
5. **Amateur UX** - Not production-ready

## Critical Requirements
1. **config.yaml format MUST be compatible with build-and-deploy.sh**
2. **Professional TUI matching build-and-deploy.sh style**
3. **Minimal prompts - get the job done efficiently**
4. **Clear visual hierarchy and flow**

## New Architecture

### Phase 1: Container Runtime (Quick & Clean)
```
╔══════════════════════════════════════════════════════════════════════╗
║                    AI DevKit Configuration v1.0                       ║
╚══════════════════════════════════════════════════════════════════════╝

Detecting container environment...
  ✓ Found: nerdctl, podman
  ✓ Runtime: k3s

Select build tool:
  → nerdctl (k3s)
    podman
```

### Phase 2: Repository Configuration (Professional TUI)
```
╔══════════════════════════════════════════════════════════════════════╗
║                    Repository Configuration                           ║
╚══════════════════════════════════════════════════════════════════════╝

┌─────────────────────────┐ Components ┌──────────────────────────────┐
│ → ○ Python 3.11         │            │ Select a component           │
│   ○ Node.js 20          │            │ to configure                 │
│   ○ Go 1.22            │            │                              │
│   ○ Maven              │            │                              │
│   ○ Rust               │            │                              │
│   ○ SBT                │            │                              │
└─────────────────────────┘            └──────────────────────────────┘

[N]exus  [S]ave  [Q]uit                          0 configured
```

When component selected:
```
┌─────────────────────────┐ Python 3.11 ┌─────────────────────────────┐
│ → ✓ Python 3.11         │             │ Current: Not configured      │
│   ○ Node.js 20          │             │                              │
│   ○ Go 1.22            │             │ 1) PyPI (recommended)        │
│   ○ Maven              │             │ 2) pypi-proxy (Nexus)        │
│   ○ Rust               │             │ 3) Custom URL                │
│   ○ SBT                │             │ 4) Clear                     │
└─────────────────────────┘             └──────────────────────────────┘

Select: _
```

## Implementation Strategy

### 1. Create Minimal Scaffolding (`configure-ai-devkit-v2.sh`)
```bash
#!/bin/bash

# === Configuration ===
VERSION="1.0.0"
CONFIG_DIR="$HOME/.ai-devkit"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

# === Phase 1: Container Runtime ===
configure_container_runtime() {
    # Detection and selection - minimal output
}

# === Phase 2: Repository Configuration ===
configure_repositories() {
    # Professional TUI
}

# === Main ===
main() {
    configure_container_runtime
    configure_repositories
}

main "$@"
```

### 2. Test Functions Separately
- `test-runtime-detection.sh` - Test container detection
- `test-repo-tui.sh` - Test repository TUI
- `test-config-output.sh` - Verify config.yaml format

### 3. Key Principles
- **Silent by default** - Only show what matters
- **Single responsibility** - Each function does one thing
- **Consistent style** - Match build-and-deploy.sh
- **Proper error handling** - Fail gracefully
- **No duplicate questions** - Ask once, use everywhere

## Config Output Format (MUST match build-and-deploy.sh expectations)

```yaml
# Container configuration
container:
  build_command: "sudo nerdctl --address /run/k3s/containerd/containerd.sock"
  runtime: "k3s"
  runtime_import: "direct"

# Nexus configuration (if configured)
nexus:
  enabled: true
  url: "http://localhost:8081"
  auth:
    type: "basic"
    username: "admin"
    password: "encrypted:xxxxx"

# Component repositories
component_repos:
  PYTHON_3_11:
    - name: "pypi-proxy"
      url: "http://localhost:8081/repository/pypi-proxy"
      type: "local_readonly"
      auth: "inherit"
      primary: true
  NODEJS_20:
    - name: "npm-proxy"
      url: "http://localhost:8081/repository/npm-proxy"
      type: "local_readonly"
      auth: "inherit"
      primary: true
```

## Next Steps
1. Archive current configure-ai-devkit.sh as .bak
2. Create clean v2 with proper structure
3. Test each component separately
4. Integrate and test full flow
5. Ensure config.yaml compatibility