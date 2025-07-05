# META-build-and-deploy Documentation

> **Note**: This is a META documentation file that describes `build-and-deploy.sh` which exists in the project but whose full implementation is not shown here. This document captures the essential interfaces, behaviors, and interactions without implementation details.

## Primary Purpose

The `build-and-deploy.sh` script is the main entry point for the AI DevKit Pod Configurator. It orchestrates the entire process of:
- Presenting an interactive TUI for component selection
- Building a custom Docker image based on selected components
- Deploying the containerized environment to Kubernetes
- Setting up port forwarding for access

## Command-Line Interface

```bash
# Standard usage - shows component selection UI
./build-and-deploy.sh

# Skip component selection (uses previous selection)
./build-and-deploy.sh --no-select
```

## Key Functions/Entry Points

### Main Functions
- `main()` - Primary orchestration function
- `run_component_selection_ui()` - Interactive component selection interface
- `validate_environment()` - Prerequisite checking
- `setup_configuration()` - Nexus and git configuration
- `cleanup_previous_build()` - Remove old builds
- `build_docker_image()` - Docker image construction
- `deploy_to_kubernetes()` - K8s deployment
- `setup_port_forwarding()` - kubectl port-forward setup

### UI Functions
- `draw_box()` - Box drawing primitive
- `render_catalog()` - Component catalog display
- `render_cart()` - Selected components display
- `render_deployment_steps()` - Deployment progress visualization
- `handle_ui_input()` - Keyboard input processing

### Component Management
- `load_components()` - Parse component YAML files
- `toggle_cart_item()` - Add/remove components
- `sort_components_by_dependencies()` - Topological sort
- `create_custom_dockerfile()` - Generate Dockerfile

## Dependencies and Interactions

### External Commands Required
- `docker` - Container building
- `kubectl` - Kubernetes operations
- `colima` - Container runtime (macOS)
- `ssh-keygen` - SSH key generation
- `git` - Version control operations
- `gh` - GitHub CLI (optional)

### File System Interactions
- **Reads from**:
  - `components/` - Component definitions (YAML files)
  - `docker/Dockerfile.base` - Base Dockerfile template
  - `docker/entrypoint.base.sh` - Base entrypoint script
  - `kubernetes/*.yaml` - K8s manifests
  - `scripts/motd-ai-devkit.sh` - MOTD script
  - `VERSION` - Version information

- **Writes to**:
  - `.build-temp/` - Temporary build directory
  - `~/.ai-devkit/ssh-keys/` - SSH host keys
  - `build-and-deploy.log` - Build log file

### Kubernetes Resources
- Creates/updates:
  - Namespace: `ai-devkit`
  - Deployment: `ai-devkit`
  - PVCs: `ai-devkit-config-pvc`, `ai-devkit-workspace-pvc`
  - Secrets: `ssh-host-keys`, `git-config`
  - ConfigMaps: `nexus-proxy-config` (if Nexus available)

## Configuration and Data Structures

### Environment Variables
- `AI_DEVKIT_THEME` - UI theme selection (default/dark/matrix/ocean/minimal/neon)
- `DOCKER_BUILDKIT` - Set to 0 when using Nexus proxy

### Global Variables
- `IMAGE_NAME` - Docker image name (default: "ai-devkit")
- `IMAGE_TAG` - Docker image tag (default: "latest")
- `NAMESPACE` - Kubernetes namespace (default: "ai-devkit")
- `TEMP_DIR` - Build temporary directory (default: ".build-temp")
- `SSH_KEYS_DIR` - SSH keys location (default: "$HOME/.ai-devkit/ssh-keys")

### Component YAML Structure
```yaml
id: COMPONENT_ID
name: Component Display Name
group: component-group
requires: [dependency-groups]
description: Component description
pre_build_script: script-name.sh
installation:
  dockerfile: |
    # Docker commands
inject_files:
  - source: file.txt
    destination: /path/to/file
    permissions: 644
entrypoint_setup: |
  # Bash commands for entrypoint
```

## High-Level Workflow

1. **Initialization Phase**
   - Check prerequisites (docker, kubectl, colima)
   - Generate SSH host keys if needed
   - Load component definitions from YAML files
   - Check for Nexus proxy availability

2. **Component Selection Phase**
   - Display interactive TUI with catalog and cart
   - Handle user navigation and selection
   - Validate dependencies between components
   - Save selected components to global arrays

3. **Build Phase**
   - Clean previous build artifacts
   - Execute component pre-build scripts
   - Generate custom Dockerfile
   - Build Docker image with selected components
   - Tag image appropriately

4. **Deployment Phase**
   - Push image to Kubernetes cluster (via colima)
   - Apply Kubernetes manifests
   - Create necessary secrets and configmaps
   - Wait for pod readiness
   - Setup port forwarding

## Side Effects

### Files Created
- SSH host keys in `~/.ai-devkit/ssh-keys/`
- Temporary build files in `.build-temp/`
- Build log at `build-and-deploy.log`
- Component imports file
- Custom Dockerfile and entrypoint.sh

### Services Started
- SSH port forwarding on port 2222
- Filebrowser port forwarding on port 8090
- Background kubectl port-forward process

### Kubernetes Changes
- Deployment created/updated in ai-devkit namespace
- Persistent volumes claimed
- Secrets created for SSH and git configuration

## Critical Assumptions and Requirements

1. **Environment**:
   - Running on system with Docker and Kubernetes access
   - Colima is running with Kubernetes enabled
   - User has kubectl configured properly

2. **Permissions**:
   - Write access to home directory for SSH keys
   - Ability to create Kubernetes resources
   - Docker build permissions

3. **Network**:
   - Ports 2222 and 8090 available on localhost
   - Access to container registries (or Nexus proxy)

## Error Handling

### Validation Failures
- Missing prerequisites cause immediate exit
- Component directory absence triggers error
- Colima/Kubernetes access issues halt execution

### Build Failures
- Docker build errors logged to file
- Failed builds prevent deployment phase
- Cleanup attempted before exit

### Deployment Failures
- Kubernetes errors logged
- Port forwarding failures reported
- Pod readiness timeout handled

### Recovery Approach
- Previous deployment deleted before new one
- Temporary files cleaned on each run
- Exit codes indicate failure type

## Key Interactions

### With Component System
- Reads component definitions from `components/` directory
- Executes pre-build scripts for selected components
- Sorts components by dependency graph

### With Docker System
- Generates Dockerfile from base template
- Injects component-specific installation steps
- Builds with optional Nexus proxy arguments

### With Kubernetes
- Uses kubectl for all cluster operations
- Leverages colima for image transfer
- Manages secrets and configmaps

### With User
- Interactive TUI for component selection
- Progress visualization during deployment
- Final connection instructions display

## Exit States

- **0**: Successful build and deployment
- **1**: Error during execution (check log file)
- **User Interrupt**: Cleanup trap ensures terminal restoration
