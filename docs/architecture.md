# Architecture Overview

This document describes the architecture and design decisions of the AI DevKit Pod Configurator.

## System Overview

The AI DevKit Pod Configurator is a modular system for creating customized development environments in Kubernetes. It consists of:

1. **Component Selection TUI** - Interactive terminal interface for selecting development tools
2. **Build System** - Dynamic Docker image generation based on selections
3. **Kubernetes Deployment** - Containerized environment with persistent storage
4. **Component Framework** - Plugin-style architecture for adding tools

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        User Interface                        │
│                    (build-and-deploy.sh)                    │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                    Component System                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Agents    │  │  Languages  │  │Build Tools  │  ...   │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                     Build Engine                             │
│  • Dockerfile generation                                     │
│  • Component dependency resolution                           │
│  • Pre-build script execution                                │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 Container Runtime                            │
│  ┌──────────────────────────────┐                          │
│  │     AI DevKit Container      │                          │
│  │  • Ubuntu 22.04 base         │                          │
│  │  • Selected components       │                          │
│  │  • SSH server (port 2222)   │                          │
│  └──────────────────────────────┘                          │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                    Kubernetes                                │
│  • Persistent volumes                                        │
│  • Service exposure                                          │
│  • ConfigMaps/Secrets                                        │
└─────────────────────────────────────────────────────────────┘
```

## Component System

### Component Structure

Each component is defined by:
- **YAML definition** (`component-name.yaml`) - Metadata and installation instructions
- **Markdown documentation** (`component-name.md`) - Usage instructions
- **Optional pre-build script** - For complex setup tasks

### Component Categories

```
components/
├── agents/          # AI assistants (Claude Code, etc.)
├── languages/       # Programming languages
├── build-tools/     # Build and dependency managers
└── .../            # Extensible categories
```

### Component Lifecycle

1. **Selection** - User chooses components via TUI
2. **Dependency Resolution** - System resolves dependencies and conflicts
3. **Pre-build** - Execute any pre-build scripts
4. **Build** - Generate Dockerfile with component installations
5. **Deploy** - Create container with selected components

## Build System

### Dynamic Dockerfile Generation

The build system creates a custom Dockerfile by:

1. Starting with `docker/Dockerfile.base`
2. Inserting component installations at `LANGUAGE_INSTALLATIONS_PLACEHOLDER`
3. Adding file injections before `VOLUME` declarations
4. Configuring entrypoint setup for runtime initialization

### Build Flow

```
User Selection
     │
     ▼
Load Components ──────► Sort by Dependencies
     │                         │
     │                         ▼
     │                  Execute Pre-build Scripts
     │                         │
     ▼                         ▼
Generate Dockerfile ◄──── Component Processing
     │
     ▼
Docker Build ─────────► Push to K8s
     │
     ▼
Deploy to Kubernetes
```

## Kubernetes Architecture

### Namespace Structure

All resources are deployed to the `ai-devkit` namespace:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ai-devkit
```

### Persistent Storage

Two persistent volumes provide data persistence:

1. **Workspace Volume** (`ai-devkit-workspace-pvc`)
   - Mount: `/home/devuser/workspace`
   - Purpose: User code and projects
   - Size: 5Gi

2. **Config Volume** (`ai-devkit-config-pvc`)
   - Mount: `/home/devuser/.config/ai-devkit`
   - Purpose: General configuration persistence
   - Size: 1Gi

### Service Architecture

The deployment includes two containers:

1. **Main Container** (`ai-devkit`)
   - Development environment with selected tools
   - SSH server on port 22
   - Runs as non-root user (`devuser`)

2. **Sidecar Container** (`filebrowser`)
   - Web-based file manager
   - Port 8090
   - Access to workspace volume

### Networking

Services are exposed via `ClusterIP`:
- SSH: Port 22 → 2222 (via port-forward)
- Filebrowser: Port 8090 → 8090 (via port-forward)

## Security Considerations

### Container Security

- **Non-root execution** - Container runs as `devuser` (UID 1000)
- **No privileged access** - Standard security context
- **Isolated namespace** - Dedicated `ai-devkit` namespace

### Secret Management

Sensitive data is stored in Kubernetes secrets:
- `ssh-host-keys` - SSH server host keys
- `git-config` - Git credentials (optional)

### Network Security

- No direct external exposure (ClusterIP only)
- Port forwarding required for access
- SSH password authentication (configurable)

## Configuration Management

### Environment Variables

Components can define environment variables that are:
1. Set during build (via `ARG`)
2. Configured at runtime (via ConfigMap)
3. Passed to processes (via entrypoint)

### Nexus Proxy Support

When Nexus is detected:
- Package managers are configured to use proxy
- Build arguments are automatically added
- ConfigMaps provide runtime configuration

## File Structure

### Project Layout

```
ai-devkit-pod-configurator/
├── build-and-deploy.sh      # Main entry point
├── components/              # Component definitions
├── docker/                  # Base container files
│   ├── Dockerfile.base      # Base image definition
│   └── entrypoint.base.sh   # Runtime initialization
├── kubernetes/              # K8s manifests
│   ├── deployment.yaml      # Main deployment
│   ├── namespace.yaml       # Namespace definition
│   ├── pvc.yaml           # Persistent volumes
│   └── nexus-config.yaml   # Optional Nexus config
├── scripts/                 # Utility scripts
└── docs/                   # Documentation
```

### Container Layout

```
/home/devuser/
├── workspace/              # Persistent user workspace
├── .config/
│   └── ai-devkit/         # Persistent configuration
├── .claude/               # AI assistant files
├── .local/                # User installations
└── .bashrc                # Shell configuration
```

## Extension Points

### Adding New Components

1. Create YAML definition in appropriate category
2. Add installation instructions in `dockerfile` section
3. Optional: Add pre-build script for complex setup
4. Create documentation markdown file

### Custom Categories

New categories can be added by:
1. Creating directory under `components/`
2. Adding `.category.yaml` for metadata
3. Following standard component structure

### Theme System

The TUI supports custom themes via environment variable:
```bash
AI_DEVKIT_THEME=custom ./build-and-deploy.sh
```

## Performance Considerations

### Build Optimization

- **Layer caching** - Common installations in base image
- **Parallel downloads** - When using Nexus proxy
- **Minimal base image** - Ubuntu 22.04 with only essentials

### Runtime Performance

- **Resource limits** - Configurable CPU/memory limits
- **Volume performance** - Local persistent volumes
- **Network optimization** - Local cluster communication

## Future Architecture Considerations

### Planned Enhancements

1. **Multi-architecture support** - ARM64 and AMD64
2. **Component versioning** - Version constraints and compatibility
3. **Remote deployments** - Deploy to remote clusters
4. **Component registry** - External component sources

### Scalability

- **Multi-user** - Separate namespaces per user
- **Team workspaces** - Shared persistent volumes
- **Resource quotas** - Namespace-level limits
