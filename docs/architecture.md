# Architecture Overview

This document describes the architecture and design of the AI DevKit Pod Configurator.

## System Overview

The AI DevKit Pod Configurator is a modular system for creating customized development environments in Kubernetes. It uses a component-based architecture where users can select exactly what tools they need.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User Interface                       │
│                    (build-and-deploy.sh)                    │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                    Component System                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Agents    │  │  Languages  │  │Build Tools  │  ...    │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                     Build Engine                            │
│  • Dockerfile generation                                    │
│  • Component dependency resolution                          │
│  • Pre-build script execution                               │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                 Container Runtime                           │
│  ┌──────────────────────────────┐                          │
│  │     AI DevKit Container      │                          │
│  │  • Ubuntu 22.04 base         │                          │
│  │  • Selected components       │                          │
│  │  • SSH server (port 2222)    │                          │
│  └──────────────────────────────┘                          │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                    Kubernetes                               │
│  • Persistent volumes                                       │
│  • Service exposure                                         │
│  • ConfigMaps/Secrets                                       │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Terminal User Interface (TUI)

The TUI is built into `build-and-deploy.sh` and provides:
- Interactive component selection with multi-page support
- Real-time build status with animated progress indicators
- Theme support (6 built-in themes)
- Keyboard navigation (arrow keys and vim-style hjkl)
- Dynamic pagination based on terminal size
- Visual feedback for dependencies and conflicts

**Key Features:**
- Written in pure Bash for portability
- No external dependencies
- ANSI escape sequences for colors and positioning
- Box-drawing characters for visual structure
- Responsive design adapts to terminal size

**TUI States:**
1. **Component Selection** - Browse and select components
2. **Build Summary** - Review selections before building
3. **Deployment Status** - Real-time build and deployment progress
4. **Completion** - Connection information display

### 2. Component System

Components are the building blocks of the system. Each component is:
- Self-contained YAML definition
- Optional markdown documentation
- Optional pre-build script
- Dependency aware

**Component Structure:**
```
components/
├── agents/
│   ├── .category.yaml
│   └── [agent components]
├── languages/
│   ├── .category.yaml
│   ├── python-miniconda.yaml
│   └── python-miniconda.md
└── build-tools/
    ├── .category.yaml
    ├── maven.yaml
    └── maven.md
```

**Component YAML Schema:**
```yaml
id: COMPONENT_ID
name: Display Name
version: "1.0.0"
group: mutual-exclusion-group
requires: [dependency-groups]
description: Brief description
installation:
  dockerfile: |
    # Docker commands
  nexus_config: |
    # Optional Nexus-specific config
inject_files:
  - source: file.txt
    destination: /path/to/file
    permissions: 644
entrypoint_setup: |
  # Runtime initialization
```

### 3. Build Engine

The build engine handles:

#### Component Loading
- Discovers categories from directories
- Parses YAML definitions
- Validates component structure
- Builds dependency graph

#### Dependency Resolution
- Topological sort for installation order
- Validates dependency availability
- Detects circular dependencies
- Handles mutual exclusion groups

#### Dockerfile Generation
- Starts from `docker/Dockerfile.base`
- Injects component installations
- Handles file copying
- Configures entrypoint setup

#### Pre-build Scripts
- Executes component-specific setup
- Generates dynamic configurations
- Aggregates documentation
- Prepares build context

### 4. Optional Components

The system supports various optional components that can be selected during build:

#### AI Assistants
- **Claude Code** - Advanced AI coding assistant with autonomous capabilities
- Other AI tools can be added as components

#### Programming Languages
- Multiple versions of Python, Java, Go, Rust, Ruby, Scala, Kotlin
- Each language is a separate component with proper dependency management

#### Build Tools
- Maven, Gradle, SBT
- Automatically configured for Nexus proxy when available

Each component can include:
- Installation instructions
- Runtime configuration
- Documentation for AI assistants
- Pre-build scripts for complex setup

### 5. Container Image

Built on Ubuntu 22.04 LTS with:

**Base Tools** (always included):
- Git with GitHub CLI
- SSH server (OpenSSH)
- Filebrowser web UI
- Node.js 20.18.0
- Microsoft TUI Test
- Basic development utilities

**User Configuration**:
- Non-root user: `devuser` (UID 1000)
- Home directory: `/home/devuser`
- Sudo access without password
- Default shell: bash

**Persistent Paths**:
- `/home/devuser/workspace` - Code and projects
- `/home/devuser/.config` - User configuration

**Service Ports**:
- 2222: SSH server
- 8090: Filebrowser web UI

### 6. Kubernetes Deployment

The deployment includes:

#### Pod Structure
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-devkit
spec:
  template:
    spec:
      containers:
      - name: main
        image: ai-devkit:latest
        ports:
        - containerPort: 22
      - name: filebrowser
        image: filebrowser/filebrowser
        ports:
        - containerPort: 8090
```

#### Persistent Storage
- **workspace-data**: 10Gi for user code
- **config-data**: 1Gi for configuration
- Storage class: Default (cluster-dependent)

#### Services
- **ClusterIP Service**: Internal access only
- **Port Forwarding**: Local development access
- No external LoadBalancer by default

#### Secrets
- **ssh-host-keys**: Persistent SSH identity
- **git-config**: Optional git credentials

#### ConfigMaps
- **nexus-config**: Optional proxy settings

## Data Flow

### Build Process

```
┌─────────────────────────────┐
│   Run build-and-deploy.sh   │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│   TUI Component Selection   │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Load Component Definitions │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│    Resolve Dependencies     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Execute Pre-build Scripts  │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│    Generate Dockerfile      │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│   Build Container Image     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│   Deploy to Kubernetes      │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│   Setup Port Forwarding     │
└─────────────────────────────┘
```

### Component Installation Flow

1. **Selection**: User selects components in TUI
2. **Validation**: Check dependencies and conflicts
3. **Sorting**: Topological sort by dependencies
4. **Pre-build**: Run component pre-build scripts
5. **Generation**: Create Dockerfile with installations
6. **Building**: Docker builds the image
7. **Deployment**: Image deployed to Kubernetes

## Security Architecture

### Container Security
- Runs as non-root user (`devuser`)
- SSH requires authentication (password: devuser)
- Minimal base image (Ubuntu 22.04)
- No unnecessary privileges
- Sudo access for development needs

### Secret Management
- SSH host keys in Kubernetes secrets
- Git credentials isolated to container
- Optional host credential injection
- Proper file permissions (600 for keys)
- No secrets in image layers

### Network Security
- Services use ClusterIP (not exposed externally)
- Port forwarding for local access only
- SSH on non-standard port (2222)
- Filebrowser requires authentication
- No public LoadBalancer by default

## Extension Points

### Adding New Components

1. Create category directory under `components/`
2. Add `.category.yaml` for metadata
3. Create component YAML definition
4. Optional: Add markdown documentation
5. Optional: Create pre-build script
6. Define dependencies via `requires` field

### Custom Themes

Themes are defined in `build-and-deploy.sh`:
```bash
"custom-theme")
    CATALOG_BORDER_COLOR="$COLOR_BRIGHT_CYAN"
    CATALOG_TITLE_STYLE="$BOLD_CYAN"
    # ... more color definitions
    ;;
```

Available style elements:
- Border and box colors
- Title and text styles
- Icon colors
- Status indicators
- Animation colors

### Pre-build Scripts

Components can include pre-build scripts that:
- Generate configuration files
- Download additional resources
- Create documentation aggregates
- Set up component-specific structures

## Configuration Management

### Host Configuration
- Git credentials via `configure-git-host.sh`
- Stored in `~/.ai-devkit/`
- Injected as Kubernetes secrets
- Includes GitHub CLI authentication

### Container Configuration
- Environment variables for tools
- Dotfiles in home directory
- Package manager configurations
- Persistent across restarts
- Component-specific configs

### Nexus Proxy Support (Optional)
- Auto-detected on port 8081
- Configures package managers:
  - npm registry
  - pip index URL
  - Maven repositories
  - Go proxy
  - APT proxy
- Transparent to components
- Falls back gracefully

## Performance Considerations

### Build Optimization
- Minimal base image
- Docker layer caching
- Conditional installations
- Cleanup after each component
- Parallel downloads when possible

### Runtime Performance
- Resource limits in Kubernetes
- Efficient file watching
- Lazy loading of tools
- Minimal background processes
- SSH connection pooling

### TUI Performance
- Direct terminal manipulation
- Minimal screen updates
- Efficient pagination
- Responsive to terminal size
- Animation frame limiting

## Monitoring and Debugging

### Build Logs
- Detailed logging to `build-and-deploy.log`
- Component installation tracking
- Error capture with context
- Dockerfile generation logs
- Pre-build script output

### Runtime Debugging
- SSH access for troubleshooting
- Container logs: `kubectl logs -n ai-devkit`
- Filebrowser for file inspection
- Standard Kubernetes tooling

## Technical Decisions

### Why Bash for TUI?
- No additional dependencies
- Works on all POSIX systems
- Direct terminal control
- Fast and responsive
- Universal availability

### Why YAML for Components?
- Human readable
- Simple parsing in bash
- Widely understood
- Supports multiline strings
- Good for configuration

### Why Ubuntu Base?
- Excellent package availability
- Long-term support (LTS)
- Familiar to developers
- Good container support
- Regular security updates

### Why Kubernetes?
- Persistent storage management
- Service discovery
- Secret management
- Platform agnostic
- Industry standard

## Future Considerations

### Scalability
- Multi-user support
- Remote cluster deployment
- Team workspaces
- Shared component libraries

### Extensibility
- Plugin architecture
- External component sources
- Custom hook types
- API for automation

### Performance
- Build caching service
- Distributed builds
- Component registry
- Incremental updates
