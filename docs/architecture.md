# Architecture Overview

This document describes the architecture and design of the AI DevKit Pod Configurator.

## System Overview

The AI DevKit Pod Configurator is a modular system for creating customized development environments in Kubernetes. It uses a component-based architecture where users can select exactly what tools they need, with sophisticated dependency management and dynamic configuration generation.

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
│  │   Agents    │  │  Languages  │  │Build Tools  │  Tools  │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                     Build Engine                            │
│  • YAML parsing with yq/jq                                  │
│  • Dockerfile generation                                    │
│  • Component dependency resolution                          │
│  • Pre-build script execution                               │
│  • Permission aggregation                                   │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                 Container Runtime                           │
│  ┌──────────────────────────────┐                          │
│  │     AI DevKit Container      │                          │
│  │  • Ubuntu 22.04 base         │                          │
│  │  • Selected components       │                          │
│  │  • SSH server (port 2222)    │                          │
│  │  • Filebrowser (port 8090)   │                          │
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
- No external UI framework dependencies
- ANSI escape sequences for colors and positioning
- Box-drawing characters for visual structure
- Responsive design adapts to terminal size
- Animated spinners for deployment progress

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
- Can define command permissions

**Component Structure:**
```
components/
├── agents/
│   ├── .category.yaml
│   ├── claude-code.yaml
│   └── claude-code/
│       ├── claude-code-setup.sh
│       ├── agents/
│       ├── commands/
│       └── scripts/
├── languages/
│   ├── .category.yaml
│   ├── python-3.11.yaml
│   └── python-3.11.md
└── build-deploy/
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
command_permissions:
  allow: ["Bash(command:*)", "Read(*.ext)"]
  deny: ["Bash(dangerous:*)]
pre_build_script: relative/path/script.sh
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

The build engine has been significantly refactored to use modern tools:

#### Component Loading
- Uses `yq` for YAML parsing instead of sed/awk
- Discovers categories from directories
- Parses YAML definitions with proper error handling
- Validates component structure
- Builds dependency graph

#### Dependency Resolution
- Topological sort for installation order
- Validates dependency availability
- Detects circular dependencies
- Handles mutual exclusion groups
- Clear error messages for conflicts

#### Dockerfile Generation
- Starts from `docker/Dockerfile.base`
- Dynamically injects component installations
- Handles file copying via inject_files
- Configures entrypoint setup
- Preserves proper ordering

#### Pre-build Scripts
- Executes component-specific setup
- Generates dynamic configurations
- Aggregates documentation
- Processes command permissions
- Prepares build context

### 4. Key Components

#### Claude Code Integration

Claude Code is a sophisticated AI assistant component that includes:

**Team Topologies Implementation:**
- Stream-Aligned Team (Feature Developer, QA)
- Platform Team (Platform/Database Engineers)
- Enabling Team (API/Security/Performance specialists)
- Complicated Subsystem Team (Integration/Algorithm specialists)

**Autonomous Development System:**
- Product Manager orchestration (main thread)
- Kanban card-based workflow
- State persistence via JOURNAL.md
- Deterministic agent handoffs
- No reliance on hooks

**Dynamic Configuration:**
- Permission aggregation from all components
- Documentation import system
- Custom commands and scripts
- Flexible agent definitions

#### Programming Languages
- Multiple versions with mutual exclusion
- Architecture-aware installations (ARM64/AMD64)
- Package manager configuration
- Development tool integration

#### Build Tools
- Maven, Gradle, SBT
- Automatic Nexus proxy detection
- Repository configuration
- Dependency caching

### 5. Container Image

Built on Ubuntu 22.04 LTS with:

**Base Layer** (always included):
- Git with GitHub CLI
- SSH server (OpenSSH)
- Filebrowser web UI
- Basic development utilities
- Locale configuration (UTF-8)

**Dynamic Layer** (based on selections):
- Selected programming languages
- Build tools and package managers
- AI assistants with configurations
- Testing frameworks

**User Configuration**:
- Non-root user: `devuser` (UID 1000)
- Home directory: `/home/devuser`
- Sudo access without password
- Default shell: bash
- npm global directory: `~/.npm-global`

**Persistent Paths**:
- `/home/devuser/workspace` - Code and projects
- `/home/devuser/.config/ai-devkit` - User configuration

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
      - name: ai-devkit
        image: ai-devkit:latest
        ports:
        - containerPort: 22
      - name: filebrowser
        image: filebrowser/filebrowser
        ports:
        - containerPort: 8090
```

#### Persistent Storage
- **workspace-pvc**: 5Gi for user code
- **config-pvc**: 1Gi for configuration
- Storage class: Default (cluster-dependent)

#### Services
- **ClusterIP Service**: Internal access only
- **Port Forwarding**: Local development access
- No external LoadBalancer by default

#### Secrets and ConfigMaps
- **ssh-host-keys**: Persistent SSH identity
- **git-config**: Optional git credentials
- **nexus-proxy-config**: Package manager configurations
- **nexus-env-config**: Environment variables

## Data Flow

### Build Process

```
User Selection → Component Loading → Dependency Resolution → Pre-build Scripts
                                                                    ↓
Container Deploy ← Docker Build ← Dockerfile Generation ← Permission Aggregation
```

### Component Processing Pipeline

1. **Selection Phase**
   - User selects components via TUI
   - Dependencies validated in real-time
   - Conflicts prevented by mutual exclusion

2. **Pre-build Phase**
   - Execute pre-build scripts
   - Generate dynamic configurations
   - Aggregate permissions and documentation
   - Prepare build context

3. **Build Phase**
   - Generate customized Dockerfile
   - Process inject_files directives
   - Build container with selected components
   - Handle Nexus proxy if available

4. **Deployment Phase**
   - Deploy to Kubernetes
   - Configure persistent storage
   - Set up port forwarding
   - Display connection info

## Security Architecture

### Container Security
- Runs as non-root user (`devuser`)
- SSH requires authentication
- Minimal base image (Ubuntu 22.04)
- No unnecessary privileges
- Proper file permissions

### Secret Management
- SSH host keys in Kubernetes secrets
- Git credentials isolated to container
- Optional host credential injection
- Environment-specific configurations
- No secrets in image layers

### Network Security
- Services use ClusterIP (internal only)
- Port forwarding for local access
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
6. Define dependencies and permissions

### Custom Themes

Themes are defined in `build-and-deploy.sh`:
- Color definitions using ANSI codes
- Consistent styling across UI elements
- Support for 256-color terminals
- Accessibility considerations

### Pre-build Scripts

Components can include sophisticated pre-build scripts:
- Process multiple configuration files
- Generate dynamic content
- Aggregate data from other components
- Set up complex directory structures
- Handle conditional logic

## Configuration Management

### Build-time Configuration
- Component selection via TUI
- Dependency resolution
- Permission aggregation
- Dynamic file generation

### Runtime Configuration
- Environment variables
- Dotfiles in home directory
- Package manager configs
- Component-specific settings

### Nexus Proxy Support
- Auto-detection on port 8081
- Configures all package managers
- Transparent to components
- Falls back gracefully

## Performance Considerations

### Build Optimization
- Docker layer caching
- Parallel component processing where possible
- Efficient YAML parsing with yq
- Minimal base image size
- Cleanup after installations

### Runtime Performance
- Lazy loading of optional components
- Efficient file watching
- Resource limits in Kubernetes
- Optimized terminal operations

### TUI Performance
- Minimal screen updates
- Efficient pagination algorithms
- Debounced keyboard input
- Optimized animation frames

## Modern Tooling

### Replaced Legacy Approaches
- `yq` for YAML parsing (replaced sed/awk)
- `jq` for JSON processing
- Structured data handling
- Type-safe parsing

### Benefits
- More reliable parsing
- Better error messages
- Easier maintenance
- Cross-platform compatibility

## Technical Decisions

### Why yq and jq?
- Industry-standard tools
- Reliable YAML/JSON parsing
- Better than regex-based parsing
- Handles edge cases properly
- Good error reporting

### Why Component Permissions?
- Claude Code security model
- Granular control over AI capabilities
- Aggregated from all components
- Flexible allow/deny rules

### Why Team Topologies for Claude Code?
- Proven organizational patterns
- Clear separation of concerns
- Realistic development workflow
- Scalable agent architecture

### Why Separate Pre-build Scripts?
- Complex setup logic isolation
- Reusable across components
- Easier testing and debugging
- Clear separation of concerns
