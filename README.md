# Claude Code in Kubernetes

This project provides a containerized version of Claude Code running in Kubernetes, allowing you to use Anthropic's AI coding assistant in an isolated environment rather than directly on your host OS.

## Project Structure

```
claude-code-k8s/
├── Dockerfile.base         # Base container definition
├── entrypoint.sh           # Container startup script
├── build-and-deploy.sh     # Helper script for building and deploying
├── configure-git-host.sh   # Configure git credentials on host for injection
├── setup-git.sh            # Configure git within containers
├── cleanup-colima.sh       # Disk cleanup utility for Colima
├── access-filebrowser.sh   # Convenience script for accessing the file manager
├── settings.local.json.template  # Claude Code permissions template
├── CLAUDE.md.template      # Development guidelines template
├── .gitignore              # Git ignore file
├── components/             # Available languages and tools
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

# Connect to the container as the claude user
kubectl exec -it -n claude-code <pod-name> -- su - claude

# Inside the container, run Claude Code
cd workspace
claude
```

## Prerequisites

- Kubernetes cluster (k3s, minikube, colima, or any other Kubernetes distribution)
- kubectl configured to access your cluster
- Docker or other container build tool
- An Anthropic account with one of the following:
  - Claude.ai account with Max subscription
  - Anthropic Console account with Claude API access

## Features

### Core Features
- **Containerized Claude Code**: Run Anthropic's AI coding assistant in an isolated Kubernetes environment
- **Interactive Component Selection**: Choose which programming languages and tools to include
- **Persistent Git Configuration**: Configure git once, use across all deployments
- **Web-based File Manager**: Built-in Filebrowser for easy file uploads/downloads
- **Persistent Storage**: Configuration and workspace data persist across container restarts
- **Security**: Runs as non-root user with proper isolation
- **Easy Deployment**: Single script to build and deploy

### Base Development Tools
Every deployment includes these essential tools:
- **Node.js 20.18.0** - JavaScript runtime
- **npm (latest)** - Package manager
- **Git** - Version control
- **GitHub CLI (gh)** - GitHub operations
- **Claude Code** - Anthropic's AI coding assistant

## Git Configuration Management

Claude Code K8s supports persistent git configuration across container deployments. You have two options for configuring git:

### Option 1: Host-Based Configuration (Recommended)

Configure git once on your host machine and automatically inject it into all future deployments:

```bash
# Run the configuration script
./configure-git-host.sh

# Follow the prompts to:
# - Set your git name and email
# - Configure GitHub authentication with Personal Access Token (PAT)
```

The configuration is stored securely in `~/.claude-code-k8s/` on your host machine. When you run `build-and-deploy.sh`, it will detect this configuration and ask if you want to include it in the deployment.

Benefits:
- Configure once, use many times
- No need to reconfigure after each deployment
- Credentials stored securely as Kubernetes secrets
- Uses HTTPS authentication (no SSH keys needed)

To clear the stored configuration:
```bash
./configure-git-host.sh --clear
```

### Option 2: Container-Based Configuration

If you prefer to configure git separately for each container or don't want to store credentials on the host:

```bash
# Connect to the container
kubectl exec -it -n claude-code <pod-name> -- su - claude

# Run the setup script
setup-git.sh

# Choose authentication method:
# 1) Personal Access Token (PAT)
# 2) OAuth via web browser
```

This approach keeps git configuration isolated to the specific container instance.

### Security Notes

- Host configuration is stored with restrictive permissions (700/600)
- Credentials are injected as Kubernetes secrets, not built into the image
- PATs are never logged or displayed after initial setup
- All git operations use HTTPS (SSH is not supported)

## Component Selection

The build script includes an interactive component selection menu that allows you to customize your development environment.

### Using the Component Selector

When you run `./build-and-deploy.sh`:

1. An interactive menu appears showing available components
2. Navigate using:
   - **↑/↓ arrow keys** or **j/k** - Move cursor up/down
   - **←/→ arrow keys** or **h/l** - Navigate pages
   - **SPACE** - Select/deselect a component
   - **TAB** - Switch between catalog and build stack
   - **ENTER** - Build with selected components
   - **q** - Quit without building

3. Selected components show:
   - **Green ✓** - Component is selected
   - **Grey text** - Component unavailable due to mutual exclusion
   - **Yellow ○** - Component needs dependencies

### Available Components

#### Programming Languages
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

To build with base tools only:
```bash
./build-and-deploy.sh --no-select
```

## Working with Files

### Web-based File Manager (Filebrowser)

Every Claude Code deployment includes Filebrowser, a web-based file manager for easy file operations.

#### Accessing Filebrowser

1. Use the convenience script:
   ```bash
   ./access-filebrowser.sh
   ```
   Or manually start port forwarding:
   ```bash
   kubectl port-forward -n claude-code service/claude-code 8090:8090
   ```

2. Open in your browser: [http://localhost:8090](http://localhost:8090)

3. Login with default credentials:
   - Username: `admin`
   - Password: `admin`
   - **⚠️ Important**: Change the password after first login!

#### Filebrowser Features

- **Upload**: Drag & drop multiple files or entire folders
- **Download**: Select files/folders and download as ZIP
- **Edit**: Built-in text editor with syntax highlighting
- **Search**: Find files quickly across your workspace
- **Preview**: View images, PDFs, and other file types

### Command Line File Transfer

You can also use `kubectl cp` for command-line file transfers:

```bash
# Copy from local to container
kubectl cp /local/path/to/file claude-code/<pod-name>:/home/claude/workspace/file -n claude-code

# Copy from container to local
kubectl cp claude-code/<pod-name>:/home/claude/workspace/file /local/destination/path -n claude-code
```

## Claude Code Usage

Once connected to the container, you can use Claude Code for various tasks:

```bash
# Start Claude Code in the current directory
claude

# Get help
claude --help

# Work with specific files
claude myfile.py

# Use with a specific instruction
claude "add error handling to this function" myfile.js
```

### Authentication

On first run, Claude Code will prompt for authentication:
1. Choose OAuth (recommended) or API key
2. Follow the authentication flow
3. Your credentials are stored in the persistent volume

## Customization Options

### Resource Limits

Edit `kubernetes/deployment.yaml` to adjust CPU and memory limits:

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

### Persistence

The deployment uses persistent volume claims for:
- **Config storage**: `/home/claude/.config/claude-code` - Claude Code settings
- **Workspace**: `/home/claude/workspace` - Your code and projects

### Adding Custom Components

To add new languages or tools:

1. Create a YAML file in `components/languages/` or `components/build-tools/`
2. Follow the existing format:
   ```yaml
   id: UNIQUE_ID
   name: Display Name
   group: version-group  # For mutually exclusive options
   requires: []          # Dependencies
   description: Brief description
   installation:
     dockerfile: |
       RUN installation commands
   ```

## Troubleshooting

### Common Issues

1. **Pod stuck in Pending state**:
   ```bash
   # Check for disk pressure (common with Colima)
   ./cleanup-colima.sh
   
   # Or increase Colima disk size
   colima stop
   colima delete
   colima start --kubernetes --disk 100
   ```

2. **Authentication failures**:
   - Ensure you have an active Anthropic account
   - Check network connectivity from the container
   - Try re-running `setup-git.sh` if git operations fail

3. **Component selection issues**:
   - Yellow items need dependencies (e.g., Scala needs Java)
   - Grey items are mutually exclusive with your selection
   - Use TAB to switch between catalog and cart views

### Viewing Logs

```bash
# Container logs
kubectl logs -n claude-code <pod-name> -c claude-code

# Filebrowser logs
kubectl logs -n claude-code <pod-name> -c filebrowser

# Claude Code logs (from inside the container)
cat /home/claude/.config/claude-code/logs/*
```

## Security Considerations

- Container runs as non-root user (`claude`)
- Git credentials are injected as Kubernetes secrets
- File operations are restricted to the workspace
- Pre-configured permissions in `settings.local.json`
- No SSH support - all git operations use HTTPS

## Development Workflow

1. **Initial Setup**:
   ```bash
   ./configure-git-host.sh  # One-time git configuration
   ./build-and-deploy.sh    # Build and deploy with components
   ```

2. **Connect and Work**:
   ```bash
   kubectl exec -it -n claude-code <pod-name> -- su - claude
   cd workspace
   git clone https://github.com/yourusername/project.git
   cd project
   claude
   ```

3. **File Management**:
   - Use Filebrowser for uploading/downloading files
   - Or use `kubectl cp` for command-line transfers

4. **Iterate**:
   - Make changes with Claude Code
   - Commit and push using pre-configured git
   - Redeploy as needed (git config persists)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

Claude Code itself is a product of Anthropic and subject to Anthropic's terms of service. This project provides containerization and deployment scripts only, and does not modify or redistribute Claude Code itself.
