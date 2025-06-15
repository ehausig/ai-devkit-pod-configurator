# Claude Code in Kubernetes

This project provides a modular, plugin-based system for creating containerized development environments in Kubernetes, with optional support for Anthropic's Claude Code AI assistant.

> **Note**: This project is a work in progress and has been tested on macOS with Colima and a local Nexus server for proxy repositories. Nexus integration is optional - the system works perfectly without it.

## Architecture

The project uses a modular, plugin-style architecture:

- **Base Container**: Minimal Ubuntu 22.04 with only Git and GitHub CLI
- **Component System**: Add languages, tools, and AI agents as needed
- **Pre-build Scripts**: Components can execute setup scripts during build
- **File Injection**: Components can inject configuration files into the container

### Component Categories:
- `languages/` - Programming languages (Node.js, Python, Java, etc.)
- `build-tools/` - Build and dependency management tools
- `agents/` - AI assistants like Claude Code

### Key Features:
- Claude Code is optional, not required
- Fully modular - build containers with only what you need
- Pre-build script system for dynamic configuration
- Memory content system for AI agent awareness

## Project Structure

```
claude-code-k8s/
├── Dockerfile.base         # Base container definition
├── entrypoint.sh           # Container startup script
├── build-and-deploy.sh     # Main build and deployment script
├── configure-git-host.sh   # Configure git credentials on host for injection
├── setup-git.sh            # Configure git within containers
├── cleanup-colima.sh       # Disk cleanup utility for Colima
├── access-filebrowser.sh   # Convenience script for accessing the file manager
├── .gitignore              # Git ignore file
├── components/             # Available languages and tools
│   ├── agents/             # AI assistants
│   │   ├── claude-code.yaml
│   │   ├── claude-code-setup.sh
│   │   ├── CLAUDE.md.template
│   │   └── settings.local.json.template
│   ├── languages/          # Programming language components
│   └── build-tools/        # Build tool components
├── kubernetes/
│   ├── namespace.yaml      # Kubernetes namespace definition
│   ├── pvc.yaml            # Persistent volume claims for configuration and workspace
│   ├── deployment.yaml     # Deployment configuration (includes Filebrowser)
│   └── nexus-config.yaml   # Nexus proxy configuration (if using Nexus)
└── README.md               # This documentation
```

## Quickstart

If you're using Colima for local Kubernetes development on macOS:

```bash
# Clone the repository
git clone https://github.com/yourusername/claude-code-k8s.git
cd claude-code-k8s

# Make the scripts executable
chmod +x *.sh

# (Optional) Configure git credentials on host for automatic injection
./configure-git-host.sh

# Build and deploy with interactive component selection
./build-and-deploy.sh

# Connect to the container as the devuser
kubectl exec -it -n claude-code <pod-name> -- su - devuser

# Inside the container, if Claude Code was selected:
cd workspace
claude
```

## Prerequisites

- Kubernetes cluster (k3s, minikube, colima, or any other Kubernetes distribution)
- kubectl configured to access your cluster
- Docker or other container build tool
- If using Claude Code:
  - An Anthropic account with one of the following:
    - Claude.ai account with Max subscription
    - Anthropic Console account with Claude API access

## Features

### Core Features
- **Modular Component System**: Choose exactly what tools and languages you need
- **Optional Claude Code**: AI coding assistant available as an optional component
- **Interactive Component Selection**: Visual menu for choosing components
- **Dynamic Memory System**: Generates customized CLAUDE.md when Claude Code is selected
- **Pre-build Script System**: Components can run setup scripts during build
- **Persistent Git Configuration**: Configure git once, use across all deployments
- **Web-based File Manager**: Built-in Filebrowser for easy file uploads/downloads
- **Persistent Storage**: Configuration and workspace data persist across container restarts
- **Nexus Proxy Support**: Optional integration with Nexus Repository Manager for offline builds
- **Security**: Runs as non-root user (devuser) with proper isolation

### Base Development Tools
Every deployment includes these minimal essential tools:
- **Git** - Version control
- **GitHub CLI (gh)** - GitHub operations

All other tools, including Node.js and Claude Code, are optional components you can select.

## Component Selection

The build script includes an interactive component selection menu that allows you to customize your development environment.

### Using the Component Selector

When you run `./build-and-deploy.sh`:

1. An interactive menu appears showing available components organized by category
2. Navigate using:
   - **↑/↓ arrow keys** or **j/k** - Move cursor up/down
   - **←/→ arrow keys** or **h/l** - Navigate pages
   - **SPACE** - Select/deselect a component
   - **TAB** - Switch between catalog and build stack
   - **ENTER** - Build with selected components
   - **q** - Quit without building

3. Component states:
   - **Green ✓** - Component is selected
   - **Grey text** - Component unavailable due to mutual exclusion
   - **Yellow (needs X)** - Component requires dependencies

### Available Components

#### AI Agents
- **Claude Code**: Anthropic's AI coding assistant (requires Node.js - automatically added)

#### Programming Languages
- **Node.js**: 20.18.0 with npm
- **Python**: 3.10 (Ubuntu Default), 3.11 (Official), Miniconda
- **Java**: OpenJDK 11/17/21, Eclipse Adoptium 11/17/21
- **Go**: 1.21, 1.22
- **Ruby**: System package, 3.3 via rbenv
- **Rust**: Stable channel, Nightly channel
- **JavaScript/TypeScript**: TypeScript support
- **Scala**: 2.13, 3.x (requires Java)
- **Kotlin**: Latest version (requires Java)

#### Build Tools
- **Maven**: Java build automation
- **Gradle**: Build tool for Java/Kotlin/Groovy
- **SBT**: Scala build tool

### Skip Component Selection

To build with base tools only (minimal container with just Git and GitHub CLI):
```bash
./build-and-deploy.sh --no-select
```

## Claude Code Memory System (When Claude Code is Selected)

When you select Claude Code, the project features an intelligent memory system that generates a customized `CLAUDE.md` file for each deployment:

1. **Universal Development Guidelines**:
   - Communication style preferences
   - Git commit conventions (Conventional Commits)
   - Code philosophy and best practices
   - Git workflow automation tips

2. **Tool-Specific Guidelines**:
   - Automatically extracted from selected components
   - Includes usage examples, common commands, and tips
   - Preserves rich markdown formatting

### Component Memory Content

Each component can include a `memory_content` section that provides:
- Quick reference commands
- Tool-specific best practices
- Version-specific features
- Common workflows and examples

This content is automatically included in Claude's memory when Claude Code is selected.

## Git Configuration Management

The project supports persistent git configuration across container deployments:

### Option 1: Host-Based Configuration (Recommended)

Configure git once on your host machine:

```bash
# Run the configuration script
./configure-git-host.sh

# Follow the prompts to:
# - Set your git name and email
# - Configure GitHub authentication with Personal Access Token (PAT)
```

Configuration is stored in `~/.claude-code-k8s/` and automatically injected into deployments.

### Option 2: Container-Based Configuration

Configure git within each container:

```bash
# Connect to the container
kubectl exec -it -n claude-code <pod-name> -- su - devuser

# Run the setup script
setup-git.sh
```

## Working with Files

### Web-based File Manager (Filebrowser)

Every deployment includes Filebrowser for easy file management:

```bash
# Use the convenience script:
./access-filebrowser.sh

# Or manually:
kubectl port-forward -n claude-code service/claude-code 8090:8090
```

Access at [http://localhost:8090](http://localhost:8090)
- Default credentials: admin/admin (change after first login!)

## Creating Custom Components

Components are defined in YAML files with the following structure:

```yaml
id: COMPONENT_ID
name: Display Name
group: component-group
requires: dependency-groups  # e.g., nodejs-version
description: Component description
pre_build_script: setup-script.sh  # Optional
installation:
  dockerfile: |
    # Installation commands
  inject_files:
    - source: config-file
      destination: /path/in/container
      permissions: 644
memory_content: |
  # Documentation for AI agents
```

### Pre-build Scripts

Pre-build scripts receive these arguments:
1. `$1` - TEMP_DIR (where to place generated files)
2. `$2` - SELECTED_IDS (space-separated list)
3. `$3` - SELECTED_NAMES (space-separated list)
4. `$4` - SELECTED_YAML_FILES (space-separated list)
5. `$5` - SCRIPT_DIR (directory containing the script)

Example component categories you could add:
- `components/databases/` - Database clients
- `components/cloud/` - Cloud provider CLIs
- `components/devops/` - Infrastructure tools
- `components/testing/` - Testing frameworks

## Container Access

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n claude-code -l app=claude-code -o jsonpath="{.items[0].metadata.name}")

# Connect to container
kubectl exec -it -n claude-code $POD_NAME -c claude-code -- su - devuser

# If Claude Code was selected:
claude --help
```

## Troubleshooting

### Common Issues

1. **Claude Code not found**:
   - Ensure you selected Claude Code during the build process
   - Claude Code is now optional and must be explicitly selected

2. **No Node.js available**:
   - Node.js is no longer included by default
   - Select it from the Languages category if needed

3. **Pod stuck in Pending state**:
   ```bash
   # Check for disk pressure (common with Colima)
   ./cleanup-colima.sh
   ```

4. **Component not appearing**:
   - Check YAML syntax, especially the `requires` field (should not use brackets)
   - Verify category `.category.yaml` file exists
   - Check component group doesn't conflict with others

### Viewing Logs

```bash
# Container logs
kubectl logs -n claude-code $POD_NAME -c claude-code

# Build issues - check the temp directory
ls -la .build-temp/
```

## Security Considerations

- Container runs as non-root user (`devuser`)
- Git credentials are injected as Kubernetes secrets
- No SSH support - all git operations use HTTPS
- Minimal base image with only essential tools

## Development Workflow

1. **Initial Setup**:
   ```bash
   ./configure-git-host.sh  # One-time git configuration
   ./build-and-deploy.sh    # Select components and deploy
   ```

2. **Minimal Container** (just Git and GitHub CLI):
   ```bash
   ./build-and-deploy.sh --no-select
   ```

3. **With Claude Code**:
   - Select Claude Code from AI Agents category
   - Node.js will be automatically included
   - CLAUDE.md will be generated with your tool selections

## Support This Project

If you find this project useful, please consider supporting its development:

☕ [Buy me a coffee](https://coff.ee/ehausig)

Your support helps maintain and improve this project. Thank you!

## License

This project is licensed under the MIT License - see the LICENSE file for details.

Claude Code itself is a product of Anthropic and subject to Anthropic's terms of service. This project provides containerization and deployment scripts only, and does not modify or redistribute Claude Code itself.
