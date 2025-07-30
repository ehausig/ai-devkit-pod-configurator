# META Documentation: build-and-deploy.sh

## Overview
This is a META documentation file that describes `build-and-deploy.sh`, which exists in the project but whose full implementation is not shown here. This file serves as a reference for understanding the script's interfaces, responsibilities, and interactions without exposing implementation details.

## Primary Purpose
The `build-and-deploy.sh` script is the main entry point for the AI DevKit Pod Configurator. It provides an interactive Terminal User Interface (TUI) for selecting development components and orchestrates the complete build and deployment process of customized development environments to Kubernetes.

## Key Responsibilities
- Present an interactive component selection interface with theme support
- Validate the runtime environment and dependencies
- Generate custom Docker images based on selected components
- Deploy containerized environments to Kubernetes
- Setup port forwarding for SSH and web access
- Manage component dependencies and conflicts
- Handle pre-build scripts and component aggregation

## Command-Line Interface

### Basic Usage
```bash
./build-and-deploy.sh [options]
```

### Options
- `--no-select` - Skip the interactive component selection (use previous selection)

### Environment Variables
- `AI_DEVKIT_THEME` - Select TUI theme (default, dark, matrix, ocean, minimal, neon)
- `DOCKER_BUILDKIT` - Docker BuildKit setting (automatically managed)

## Key Functions and Entry Points

### Main Entry Points
- `main()` - Primary orchestration function
- `run_component_selection_ui()` - Interactive TUI for component selection

### Core Workflow Functions
- `validate_environment()` - Check prerequisites and system requirements
- `load_components()` - Load component definitions from YAML files
- `create_custom_dockerfile()` - Generate Dockerfile based on selections
- `build_docker_image()` - Build container image
- `deploy_to_kubernetes()` - Deploy to K8s cluster
- `setup_port_forwarding()` - Establish kubectl port-forward

### UI Functions
- `draw_box()` - Render TUI boxes
- `render_catalog()` - Display available components
- `render_cart()` - Show selected components
- `render_deployment_steps()` - Show build/deploy progress

### Component Management
- `toggle_cart_item()` - Add/remove components
- `requirements_met()` - Validate dependencies
- `sort_components_by_dependencies()` - Topological sort

## Dependencies and Interactions

### External Commands Required
- `docker` - Container image building
- `kubectl` - Kubernetes operations
- `colima` - Container runtime (macOS)
- `yq` - YAML parsing
- `jq` - JSON processing
- `ssh-keygen` - SSH key generation

### File System Interactions
- **Reads from:**
  - `components/*/` - Component YAML definitions
  - `docker/Dockerfile.base` - Base Dockerfile template
  - `docker/entrypoint.base.sh` - Base entrypoint script
  - `kubernetes/*.yaml` - K8s manifests
  - `VERSION` - Version information
  - `~/.ai-devkit/` - Host configuration

- **Writes to:**
  - `.build-temp/` - Temporary build directory
  - `~/.ai-devkit/ssh-keys/` - SSH host keys
  - `build-and-deploy.log` - Build/deployment logs

### Kubernetes Resources
- Creates namespace: `ai-devkit`
- Creates secrets: `ssh-host-keys`, `git-config`
- Applies manifests: `namespace.yaml`, `pvc.yaml`, `deployment.yaml`
- Optional: `nexus-config.yaml`

## Data Structures and Formats

### Component YAML Structure
```yaml
id: COMPONENT_ID
name: Display Name
version: "1.0.0"
group: component-group
requires: [dependency-groups]
description: Component description
installation:
  dockerfile: |
    # Docker commands
entrypoint_setup: |
  # Setup commands
command_permissions:
  allow: []
  deny: []
```

### Arrays Maintained
- `ids[]` - Component identifiers
- `names[]` - Display names
- `groups[]` - Mutual exclusion groups
- `requires[]` - Dependencies
- `in_cart[]` - Selection state
- `categories[]` - Component categories
- `yaml_files[]` - Source files

## High-Level Workflow

1. **Initialization Phase**
   - Validate environment prerequisites
   - Generate SSH host keys if needed
   - Load component definitions from YAML files
   - Initialize theme system

2. **Configuration Phase**
   - Check for Nexus proxy availability
   - Prompt for host git configuration usage

3. **Component Selection Phase**
   - Display interactive TUI
   - Handle user navigation and selection
   - Validate dependencies and conflicts
   - Show selection summary

4. **Build Phase**
   - Clean previous builds
   - Execute pre-build scripts
   - Generate custom Dockerfile
   - Build Docker image

5. **Deployment Phase**
   - Push image to container runtime
   - Create Kubernetes secrets
   - Apply Kubernetes manifests
   - Wait for pod readiness

6. **Finalization Phase**
   - Setup port forwarding
   - Display connection information

## Side Effects

### Files Created
- SSH host keys in `~/.ai-devkit/ssh-keys/`
- Temporary build artifacts in `.build-temp/`
- Build logs in `build-and-deploy.log`
- Docker image: `ai-devkit:latest`

### Services Started
- `kubectl port-forward` process for SSH (2222) and web (8090) access

### Kubernetes Changes
- Namespace created/updated
- Persistent volume claim created
- Deployment created/updated
- Secrets created/updated

## Critical Assumptions

### Environment
- Kubernetes cluster is accessible
- User has kubectl configured
- Container runtime is available
- User has appropriate permissions

### File Structure
- Script runs from project root
- `components/` directory exists
- Base Docker files exist in `docker/`
- Kubernetes manifests in `kubernetes/`

## Configuration Dependencies

### Required Files
- `docker/Dockerfile.base`
- `docker/entrypoint.base.sh`
- `kubernetes/namespace.yaml`
- `kubernetes/pvc.yaml`
- `kubernetes/deployment.yaml`

### Optional Configuration
- Nexus proxy auto-detection at `http://localhost:8081`
- Git configuration in `~/.ai-devkit/git-config/`
- GitHub CLI config in `~/.ai-devkit/github/`

## Error Handling

### Validation Failures
- Missing dependencies trigger immediate exit
- Component directory absence is fatal
- Kubernetes access issues abort execution

### Build Failures
- Docker build errors are logged
- Failed builds prevent deployment
- Errors shown in TUI with log references

### Deployment Failures
- Kubernetes errors are captured
- Port forwarding failures are non-fatal
- User prompted to check logs

## Key Interactions

### With Component System
- Reads component definitions from `components/*/`
- Executes pre-build scripts if defined
- Aggregates command permissions
- Handles dependency resolution

### With Docker
- Generates custom Dockerfile
- Builds with optional Nexus proxy
- Tags as `ai-devkit:latest`

### With Kubernetes
- Creates isolated namespace
- Manages persistent storage
- Injects configuration secrets
- Monitors deployment status

### With User
- Interactive TUI for selections
- Real-time build progress
- Connection information display
- Theme customization support

## Terminal UI Features

### Navigation
- Arrow keys / vim keys for movement
- Space for selection
- Tab to switch views
- Enter to confirm
- Q to quit

### Visual Elements
- Box drawing with Unicode characters
- Animated progress indicators
- Color-coded status updates
- Pagination for long lists
- Dependency warnings

## Performance Considerations
- Components loaded once at startup
- Minimal screen redraws in TUI
- Efficient cursor movement
- Background animation processes
- Topological sort for dependencies
