# Architecture Overview

This document describes the architecture and design of the AI DevKit Pod Configurator.

## System Overview

The AI DevKit Pod Configurator is a modular system for creating customized development environments in Kubernetes. It uses a component-based architecture where users can select exactly what tools they need.

## High-Level Architecture

```mermaid
graph TB
    subgraph "User Layer"
        UI[User Interface<br/>build-and-deploy.sh]
    end
    
    subgraph "Component Layer"
        CS[Component System]
        subgraph "Component Categories"
            direction LR
            Agents[AI Agents]
            Languages[Languages]
            BuildTools[Build Tools]
            Testing[Testing Tools]
        end
    end
    
    subgraph "Build Layer"
        BE[Build Engine]
        DF[Dockerfile<br/>Generation]
        DR[Dependency<br/>Resolution]
        PS[Pre-build<br/>Scripts]
    end
    
    subgraph "Container Layer"
        CR[Container Runtime]
        subgraph "AI DevKit Container"
            Base[Ubuntu 22.04 LTS]
            Components[Selected Components]
            SSH[SSH Server :2222]
            FB[Filebrowser :8090]
        end
    end
    
    subgraph "Infrastructure Layer"
        K8S[Kubernetes Cluster]
        PV[Persistent Volumes]
        SVC[Services]
        CM[ConfigMaps/Secrets]
    end
    
    %% Connections
    UI --> CS
    CS --> Agents
    CS --> Languages
    CS --> BuildTools
    CS --> Testing
    
    CS --> BE
    BE --> DF
    BE --> DR
    BE --> PS
    
    BE --> CR
    CR --> Base
    CR --> Components
    CR --> SSH
    CR --> FB
    
    CR --> K8S
    K8S --> PV
    K8S --> SVC
    K8S --> CM
    
    %% Styling
    classDef userStyle fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef componentStyle fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef buildStyle fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef containerStyle fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef k8sStyle fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    
    class UI userStyle
    class CS,Agents,Languages,BuildTools,Testing componentStyle
    class BE,DF,DR,PS buildStyle
    class CR,Base,Components,SSH,FB containerStyle
    class K8S,PV,SVC,CM k8sStyle
```

## Core Components

### 1. Terminal User Interface (TUI)

The TUI is built into `build-and-deploy.sh` and provides:
- Interactive component selection
- Real-time build status
- Theme support
- Keyboard navigation
- Multi-page catalog browsing

**Key Features:**
- Written in pure Bash for portability
- Supports vim-style navigation (hjkl)
- Dynamic pagination based on terminal size
- Visual feedback for dependencies and conflicts

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
│   ├── claude-code.yaml
│   └── claude-code.md
├── languages/
│   ├── .category.yaml
│   ├── python-miniconda.yaml
│   └── python-miniconda.md
└── build-tools/
    ├── .category.yaml
    ├── maven.yaml
    └── maven.md
```

### 3. Build Engine

The build engine handles:
1. **Component Loading**: Parses YAML files and builds dependency graph
2. **Dependency Resolution**: Topological sort for correct installation order
3. **Dockerfile Generation**: Creates custom Dockerfile from base + components
4. **Pre-build Scripts**: Executes component-specific setup scripts
5. **Documentation Aggregation**: Collects component markdown files

### 4. Container Image

Built on Ubuntu 22.04 LTS with:
- **Base Tools**: Git, SSH server, file manager
- **Development User**: Non-root `devuser` with sudo access
- **Persistent Paths**: 
  - `/home/devuser/workspace` - Code and projects
  - `/home/devuser/.config/ai-devkit` - Configuration
- **Service Ports**:
  - 2222: SSH server
  - 8090: Filebrowser web UI

### 5. Kubernetes Deployment

The deployment includes:
- **Main Pod**: Development environment container
- **Sidecar**: Filebrowser for web-based file management
- **Persistent Volumes**: For workspace and configuration
- **Services**: ClusterIP for SSH and Filebrowser
- **ConfigMaps**: Nexus proxy configuration (optional)
- **Secrets**: SSH keys and git credentials

## Data Flow

### Build Process

```mermaid
graph TD
    A[User runs build-and-deploy.sh] --> B[TUI Component Selection]
    B --> C[Load Component Definitions]
    C --> D[Resolve Dependencies]
    D --> E[Execute Pre-build Scripts]
    E --> F[Generate Dockerfile]
    F --> G[Build Container Image]
    G --> H[Deploy to Kubernetes]
    H --> I[Setup Port Forwarding]
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
- SSH requires authentication
- Minimal base image
- No unnecessary privileges

### Secret Management
- SSH host keys in Kubernetes secrets
- Git credentials isolated to container
- Optional host credential injection
- Proper file permissions (600)

### Network Security
- Services use ClusterIP (not exposed externally)
- Port forwarding for local access only
- Optional network policies
- Filebrowser requires authentication

## Extension Points

### Adding New Components

1. Create YAML definition in appropriate category
2. Optional: Add markdown documentation
3. Optional: Create pre-build script
4. Define dependencies via `requires` field

### Custom Themes

Themes are defined in `build-and-deploy.sh`:
- Color schemes for TUI elements
- Icon sets
- Border styles
- Status indicators

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

### Container Configuration
- Environment variables for tools
- Dotfiles in home directory
- Package manager configurations
- Persistent across restarts

### Nexus Proxy Support (Optional)
- Proxy configuration
- ConfigMaps for each package manager
- Environment variables for tools
- Transparent to components

## Performance Considerations

### Build Optimization
- Minimal base image
- Layer caching
- Conditional installations
- Cleanup after each component

### Runtime Performance
- Resource limits in Kubernetes
- Efficient file watching
- Lazy loading of tools
- Minimal background processes

## Monitoring and Debugging

### Build Logs
- Detailed logging to `build-and-deploy.log`
- Component installation tracking
- Error capture and reporting

### Runtime Debugging
- SSH access for troubleshooting
- Container logs via kubectl
- Filebrowser for file inspection
- Standard Kubernetes tooling

## Technical Decisions

### Why Bash for TUI?
- No additional dependencies
- Works on all POSIX systems
- Direct terminal control
- Fast and responsive

### Why YAML for Components?
- Human readable
- Simple parsing
- Widely understood
- Supports multiline strings

### Why Ubuntu Base?
- Excellent package availability
- Long-term support (LTS)
- Familiar to developers
- Good container support

### Why Kubernetes?
- Persistent storage management
- Service discovery
- Secret management
- Platform agnostic
