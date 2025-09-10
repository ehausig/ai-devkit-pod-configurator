# Session Bootstrap: build-and-deploy.sh

## Overview
This session bootstrap file provides high-level documentation about `build-and-deploy.sh` to help LLMs understand the project's main entry point without requiring the full implementation. It describes the script's interfaces, responsibilities, and interactions to establish context for new LLM sessions.

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

## Dependencies

### External Commands Required
- `kubectl` - Kubernetes interaction
- `docker`/`nerdctl`/`podman` - Container building
- `yq` - YAML processing (supports both mikefarah/yq and kislyuk/yq)
- `ssh-keygen` - SSH key generation
- `sha256sum` - Checksum calculation

### Library Scripts
- `lib/config-reader.sh` - Read configuration files
- `lib/repository-loader.sh` - Load repository configurations
- `lib/credential-manager.sh` - Handle authentication
- `lib/template-processor-bash.sh` - Generate configurations
- `lib/file-mapping-manager.sh` - Stage files for deployment
- `lib/generate-dynamic-deployment.sh` - Create K8s manifests
- `lib/generate-init-scripts-configmap.sh` - Generate init container scripts

## Configuration Files

### User Configuration
- `~/.ai-devkit/config.yaml` - Main configuration file
  - Container runtime settings
  - Repository configurations
  - Credentials

### Component Definitions
- `components/*/*.yaml` - Component descriptors
- `components/*/*/ai-devkit/config.yaml` - Component configuration
- `components/*/*/ai-devkit/file-mappings.yaml` - File placement rules

### Generated Files
- `.build-temp/` - Temporary build directory
- `.build-temp/staging/` - Staged files for deployment
- `.build-temp/staging/manifest.txt` - File copy manifest

## Workflow Overview

1. **Environment Validation**
   - Check for required tools
   - Verify Kubernetes connectivity
   - Load user configuration

2. **Component Selection**
   - Display interactive TUI
   - Handle user selections
   - Validate dependencies

3. **Pre-build Phase**
   - Execute pre-build scripts
   - Generate configurations
   - Stage files

4. **Build Phase**
   - Generate Dockerfile
   - Build container image
   - Handle image import if needed

5. **Deployment Phase**
   - Generate K8s manifests
   - Create namespace
   - Deploy resources
   - Setup port forwarding

## Side Effects

### Files Created
- `.build-temp/` directory structure
- Generated Dockerfile
- K8s manifest files
- SSH host keys (if not exist)

### Kubernetes Resources
- Namespace: `ai-devkit-<checksum>`
- Deployment: `ai-devkit`
- Services: `ai-devkit-ssh`, `ai-devkit-filebrowser`
- ConfigMaps: `generated-configs`, `init-scripts`
- Secrets: `ssh-host-keys`, `git-config`
- PersistentVolumeClaims: `workspace-pvc`, `config-pvc`

### Processes Started
- `kubectl port-forward` for SSH (2222) and Filebrowser (8090)

## Error Handling

### Validation Failures
- Missing dependencies cause early exit with clear messages
- Invalid configuration prevents build

### Build Failures
- Docker build errors are captured and displayed
- Cleanup of temporary files on failure

### Deployment Failures
- Kubernetes errors shown with context
- Port forwarding retries on failure

## Key Assumptions
- User has kubectl configured and cluster access
- Container build tool is available and configured
- User has sufficient cluster permissions
- Default storage class is available in cluster

## Exit Codes
- `0` - Success
- `1` - General failure
- `130` - User interrupted (Ctrl+C)

## TUI Navigation
- **Arrow keys** or **hjkl** - Navigate
- **Space** - Select/deselect
- **Tab** - Switch sections
- **Enter** - Confirm
- **q** - Quit

## Integration Points
- Reads component definitions from `components/` directory
- Uses configuration from `~/.ai-devkit/config.yaml`
- Integrates with Kubernetes via kubectl
- Supports multiple container runtimes
- Handles both direct and save-load image import methods