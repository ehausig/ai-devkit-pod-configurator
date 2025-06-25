# Architecture Documentation

This document provides a detailed overview of the AI DevKit Pod Configurator's architecture, design decisions, and implementation details.

## Table of Contents

- [System Overview](#system-overview)
- [Core Components](#core-components)
- [Build Process](#build-process)
- [Component System Architecture](#component-system-architecture)
- [TUI Architecture](#tui-architecture)
- [Container Architecture](#container-architecture)
- [Kubernetes Architecture](#kubernetes-architecture)
- [Security Architecture](#security-architecture)
- [Data Flow](#data-flow)
- [Design Decisions](#design-decisions)

## System Overview

The AI DevKit Pod Configurator is a modular system designed to create customized development environments in Kubernetes. It follows a plugin-based architecture where functionality is added through components rather than being built into the base system.

### Key Design Principles

1. **Modularity**: Every feature beyond the base is a component
2. **Composability**: Components can depend on and work with each other
3. **Flexibility**: Users select only what they need
4. **Reproducibility**: Same selections produce identical environments
5. **Security**: Non-root execution with proper isolation

### High-Level Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│                 │     │                  │     │                 │
│  Component TUI  │────▶│  Build System    │────▶│   Kubernetes    │
│   (Selection)   │     │  (Docker Build)  │     │   Deployment    │
│                 │     │                  │     │                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                       │                         │
         ▼                       ▼                         ▼
   User Selects            Dockerfile              Running Pod with
   Components              Generated              Selected Tools
```

## Core Components

### 1. Build Script (`build-and-deploy.sh`)

The main orchestrator that:
- Presents the TUI for component selection
- Manages the build process
- Handles deployment to Kubernetes
- Provides status updates with animations

**Key Features:**
- Theme system for UI customization
- Pagination for large component lists
- Real-time build status updates
- Error handling and recovery

### 2. Component System

Located in `components/` directory:

```
components/
├── agents/          # AI assistants
├── languages/       # Programming languages
├── build-tools/     # Build automation tools
└── <custom>/        # User-defined categories
```

Each component consists of:
- **YAML Definition**: Metadata and installation instructions
- **Documentation**: Markdown file with usage information
- **Pre-build Script**: Optional setup automation
- **Templates**: Configuration files to inject

### 3. Base Container

Minimal Ubuntu 22.04 with only essential tools:
- Git and GitHub CLI
- SSH Server
- Node.js (required for TUI Test and Claude Code)
- Basic development utilities

### 4. Supporting Scripts

- `configure-git-host.sh`: Git credential management
- `cleanup-colima.sh`: Disk space maintenance
- `access-filebrowser.sh`: File manager access
- `setup-git.sh`: In-container git configuration

## Build Process

### Phase 1: Initialization

1. **Environment Validation**
   - Check prerequisites (Docker, kubectl, etc.)
   - Verify Kubernetes connectivity
   - Generate SSH host keys

2. **Component Discovery**
   - Scan `components/` directory
   - Parse category metadata
   - Load component definitions

3. **Configuration Detection**
   - Check for Nexus proxy
   - Detect host git configuration
   - Set build parameters

### Phase 2: Component Selection

1. **TUI Presentation**
   - Display available components
   - Show dependencies and conflicts
   - Handle user navigation

2. **Dependency Resolution**
   - Validate requirements
   - Handle mutual exclusions
   - Build dependency graph

3. **Selection Validation**
   - Ensure all dependencies met
   - Check for conflicts
   - Confirm selections

### Phase 3: Build Preparation

1. **Pre-build Scripts**
   - Execute component scripts
   - Generate configuration files
   - Process templates

2. **Dockerfile Generation**
   - Start with base Dockerfile
   - Insert component installations
   - Add file injections
   - Configure entrypoint

3. **Asset Collection**
   - Copy documentation files
   - Gather configuration templates
   - Prepare build context

### Phase 4: Container Build

1. **Docker Build**
   - Execute multi-stage build
   - Apply Nexus proxy if configured
   - Tag resulting image

2. **Image Distribution**
   - Save image as tar
   - Import to Kubernetes node
   - Make available to cluster

### Phase 5: Deployment

1. **Kubernetes Resources**
   - Create namespace
   - Apply PVCs for persistence
   - Create secrets (git, SSH keys)
   - Deploy pod with sidecars

2. **Service Configuration**
   - Expose SSH and Filebrowser
   - Setup port forwarding
   - Configure networking

## Component System Architecture

### Component Definition Schema

```yaml
id: UNIQUE_ID
name: Display Name
version: "1.0.0"
group: mutual-exclusion-group
requires: space-separated-dependencies
description: Brief description
pre_build_script: setup-script.sh
installation:
  dockerfile: |
    # Installation commands
  nexus_config: |
    # Proxy configuration
  inject_files:
    - source: file.conf
      destination: /path/in/container
      permissions: 644
  test_command: command --version
entrypoint_setup: |
  # Runtime setup commands
memory_content: |
  # Documentation for AI agents
```

### Dependency Management

Components can:
- **Require** other components via `requires:` field
- **Exclude** others via `group:` field
- **Enhance** others via pre-build scripts

### Pre-build Script System

Scripts receive:
1. `TEMP_DIR` - Build directory
2. `SELECTED_IDS` - Component IDs
3. `SELECTED_NAMES` - Component names
4. `SELECTED_YAML_FILES` - YAML paths
5. `SCRIPT_DIR` - Script location

Used for:
- Generating dynamic configuration
- Processing templates
- Collecting documentation
- Creating component manifests

## TUI Architecture

### Display Layout

```
┌─────────────────────────┬─────────────────────────┐
│   Available Components  │      Build Stack        │
├─────────────────────────┼─────────────────────────┤
│ ▸ ○ Component 1         │ Base Development Tools  │
│   ✓ Component 2         │   ✓ Git                 │
│   ○ Component 3         │   ✓ GitHub CLI          │
│                         │                         │
│                         │ Selected Components     │
│                         │   ✓ Python Miniconda    │
│                         │   ✓ Claude Code         │
└─────────────────────────┴─────────────────────────┘
 ↑↓ Navigate  SPACE Select  TAB Switch  ENTER Build
```

### State Management

The TUI maintains:
- Current cursor position
- Selected components array
- View state (catalog/cart)
- Pagination state
- Hint messages

### Rendering Pipeline

1. **Initial Draw**
   - Clear screen
   - Draw borders
   - Render components

2. **Incremental Updates**
   - Update only changed elements
   - Preserve static content
   - Minimize flicker

3. **Animation System**
   - Background process for spinners
   - Frame-based animation
   - Non-blocking updates

## Container Architecture

### Filesystem Layout

```
/home/devuser/
├── .config/
│   ├── claude-code/     # AI agent config
│   └── gh/              # GitHub CLI config
├── .claude/             # Claude documentation
├── workspace/           # User code (persistent)
├── .local/bin/          # User binaries
└── .npm-global/         # Node.js global packages
```

### User Management

- **Root Operations**: Package installation only
- **devuser**: Non-root user for all work
- **Permissions**: Proper ownership maintained

### Entrypoint Flow

1. Set up environment paths
2. Start SSH daemon if keys mounted
3. Configure git from secrets
4. Copy documentation files
5. Run component setup scripts
6. Switch to devuser
7. Execute user command or sleep

## Kubernetes Architecture

### Resource Structure

```yaml
Namespace: ai-devkit
├── Deployment: ai-devkit
│   ├── Container: ai-devkit (main)
│   └── Container: filebrowser (sidecar)
├── Service: ai-devkit
│   ├── Port 22 → SSH
│   └── Port 8090 → Filebrowser
├── PVC: ai-devkit-config-pvc
├── PVC: ai-devkit-workspace-pvc
├── Secret: ssh-host-keys
├── Secret: git-config (optional)
├── ConfigMap: filebrowser-config
└── ConfigMap: nexus-proxy-config (optional)
```

### Volume Mounts

1. **Persistent Volumes**
   - `/home/devuser/workspace` - Code persistence
   - `/home/devuser/.config/claude-code` - Config persistence

2. **Secrets**
   - `/etc/ssh/mounted_keys` - SSH host keys
   - `/tmp/git-mounted/` - Git configuration

3. **ConfigMaps**
   - Package manager configurations
   - Filebrowser settings

### Networking

- **ClusterIP Service**: Internal access only
- **Port Forwarding**: kubectl port-forward for external access
- **No Ingress**: Simplified security model

## Security Architecture

### Container Security

1. **Non-root Execution**
   - devuser (UID 1000) for all operations
   - sudo available but logged

2. **Minimal Base Image**
   - Ubuntu 22.04 LTS
   - Only essential packages
   - Regular security updates

3. **Secret Management**
   - Git credentials in Kubernetes secrets
   - SSH keys generated per deployment
   - No hardcoded credentials

### Network Security

1. **No External Exposure**
   - ClusterIP services only
   - Explicit port-forward required
   - SSH password authentication

2. **Isolation**
   - Namespace separation
   - Network policies compatible
   - Resource quotas applicable

## Data Flow

### Build Time

```
Component YAML → Parser → TUI Selection → Pre-build Scripts
                                              ↓
Docker Build ← Dockerfile Generator ← Component Merge
     ↓
Container Image → Kubernetes Import → Pod Creation
```

### Runtime

```
User SSH/kubectl → Pod → Entrypoint Script
                           ↓
                    Component Setup
                           ↓
                    User Environment
```

### Configuration Flow

```
Host Git Config → Kubernetes Secret → Pod Mount
                                         ↓
                                  Container Git Config
```

## Design Decisions

### Why Kubernetes?

1. **Isolation**: Each environment is isolated
2. **Persistence**: Volumes preserve work
3. **Scalability**: Multiple environments easy
4. **Standard**: Works on any Kubernetes

### Why Component System?

1. **Flexibility**: Users choose what they need
2. **Maintainability**: Components updated independently
3. **Extensibility**: Easy to add new tools
4. **Size**: Smaller images with only needed tools

### Why TUI?

1. **User Experience**: Visual selection better than config files
2. **Discoverability**: Users can see all options
3. **Validation**: Real-time feedback on selections
4. **Progress**: Visual build status

### Why Not X?

**Why not Docker Compose?**
- Less isolation between environments
- No native Kubernetes features
- Harder to manage multiple environments

**Why not Helm?**
- Too complex for single-pod deployments
- Component system simpler than Helm charts
- Direct control over build process

**Why not Dev Containers?**
- Kubernetes provides better isolation
- More flexibility in tool selection
- Better for team environments

## Future Architecture Considerations

### Planned Enhancements

1. **Component Registry**
   - Central repository for components
   - Version management
   - Dependency resolution

2. **Multi-Architecture Support**
   - Better ARM64 support
   - Architecture-specific components
   - Cross-compilation tools

3. **Enterprise Features**
   - LDAP/AD integration
   - Audit logging
   - Resource quotas

### Extension Points

1. **Custom Components**
   - Private component repositories
   - Organization-specific tools
   - Proprietary software support

2. **Build Plugins**
   - Alternative build systems
   - Cache layers
   - Security scanning

3. **Runtime Plugins**
   - Monitoring agents
   - Backup systems
   - Development metrics
