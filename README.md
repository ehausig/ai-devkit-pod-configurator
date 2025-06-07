# Claude Code in Kubernetes

This project provides a containerized version of Claude Code running in Kubernetes, allowing you to use Anthropic's AI coding assistant in an isolated environment rather than directly on your host OS.

## Project Structure

```
claude-code-k8s/
├── Dockerfile              # Container definition for Claude Code (deprecated - use Dockerfile.base)
├── Dockerfile.base         # Base container definition
├── languages.conf          # Language installation configurations
├── entrypoint.sh           # Container startup script
├── build-and-deploy.sh     # Helper script for building and deploying
├── access-filebrowser.sh   # Convenience script for accessing the file manager
├── .gitignore              # Git ignore file
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
git clone https://github.com/ehausig/claude-code-k8s.git
cd claude-code-k8s

# Make the script executable
chmod +x build-and-deploy.sh

# Build and deploy (with language selection)
./build-and-deploy.sh

# Or build without language selection (base image only)
./build-and-deploy.sh --no-select

# Connect to the container as the claude user (recommended)
kubectl exec -it -n claude-code <pod-name> -- su - claude

# Inside the container, run Claude Code
cd workspace
claude
```

On first run, follow the authentication prompts to connect your Anthropic account.

## Prerequisites

- Kubernetes cluster (k3s, minikube, colima, or any other Kubernetes distribution)
- kubectl configured to access your cluster
- Docker or other container build tool
- An Anthropic account with one of the following:
  - Claude.ai account with Max subscription
  - Anthropic Console account with Claude API access

## Detailed Setup Instructions

### 1. Building the Container

The repository includes a build script that automates the process, but you can also build manually:

```bash
# Using the script (for Colima)
./build-and-deploy.sh

# Skip language selection (base image only)
./build-and-deploy.sh --no-select

# Clean rebuild
./build-and-deploy.sh --clean

# Building manually
docker build -t claude-code:latest -f .build-temp/Dockerfile .
```

For other container systems:
- **Docker Desktop**: No additional steps needed
- **Minikube**: Use `minikube image load claude-code:latest` after building
- **k3d**: Use `k3d image import claude-code:latest` after building
- **Custom registry**: Tag and push to your registry

```bash
# Example with custom registry
docker tag claude-code:latest your-registry.com/claude-code:latest
docker push your-registry.com/claude-code:latest
```

### 2. Deploying to Kubernetes

The deployment can be done using the script or manually:

```bash
# Using the script (creates namespace, pvcs, and deployment)
./build-and-deploy.sh

# Manual deployment
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/pvc.yaml
kubectl apply -f kubernetes/deployment.yaml
```

If using a custom registry, update `kubernetes/deployment.yaml` to point to your image location.

### 3. Connecting to the Container

Find your pod and connect:

```bash
# List pods in the claude-code namespace
kubectl get pods -n claude-code

# Connect to the pod as the claude user (recommended)
kubectl exec -it -n claude-code <pod-name> -- su - claude

# Or create an alias for easy access
alias claude-exec='kubectl exec -it -n claude-code $(kubectl get pods -n claude-code -l app=claude-code -o jsonpath="{.items[0].metadata.name}") -- su - claude'
```

### 4. Authentication

When you start Claude Code for the first time, you'll be prompted to authenticate:

1. **OAuth Flow** (Recommended):
   - Claude Code will provide a URL to open in your browser
   - Sign in with your Anthropic account
   - The browser will provide an authentication code to enter back in the terminal

2. **API Key**:
   - Alternatively, you can use an Anthropic API key
   - This is obtained from your Anthropic Console account

## Features

- **Containerized Claude Code**: Run Anthropic's AI coding assistant in an isolated Kubernetes environment
- **Web-based File Manager**: Built-in Filebrowser for easy file uploads/downloads through a web UI
- **Language Selection**: Optionally include additional programming languages and tools in your container
- **Persistent Storage**: Configuration and workspace data persist across container restarts
- **Security**: Runs as non-root user with proper isolation
- **Easy Deployment**: Single script to build and deploy

## Language Support

The build script includes an interactive language selection menu. When you run the build script:

1. The screen will clear and show a list of available languages
2. Use **↑/↓ arrow keys** or **j/k** to move the cursor
3. Press **SPACE** to select/deselect a language (selected items show ✓)
4. Press **ENTER** to confirm your selections and continue
5. Press **q** to quit without building

Available languages include:

- **Python**: 3.9, 3.11, 3.12
- **Rust**: Latest stable, Nightly
- **Go**: 1.21, 1.22
- **Ruby**: 3.2, 3.3 (via rbenv)
- **Java**: Eclipse Adoptium (Temurin) 11, 17, 21
- **Scala**: 2.13, 3.x, with SBT build tool
- **.NET**: 6.0, 8.0
- **PHP**: 8.2, 8.3
- **And more**: Elixir, Kotlin, Swift

To add more languages, edit the `languages.conf` file.

### Customizing Language Options

To add or modify available languages, edit the `languages.conf` file. The format is:
```
LANGUAGE_ID|Display Name|Installation Commands
```

For example:
```
PYTHON_3_13|Python 3.13|RUN apt-get update && apt-get install -y python3.13
```

The installation commands should be valid Dockerfile RUN instructions.

## Working with Files

### Web-based File Manager (Filebrowser)

Every Claude Code deployment includes Filebrowser, a web-based file manager for easy file operations.

#### Accessing Filebrowser

1. Start port forwarding:
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
- **Terminal**: Execute commands directly (if enabled)

### Command Line File Transfer

You can still use `kubectl cp` for command-line file transfers:

```bash
# Copy from local to container
kubectl cp /local/path/to/file claude-code/<pod-name>:/home/claude/workspace/file -n claude-code

# Copy from container to local
kubectl cp claude-code/<pod-name>:/home/claude/workspace/file /local/destination/path -n claude-code

# Copy entire directories
kubectl cp /local/directory claude-code/<pod-name>:/home/claude/workspace/directory -n claude-code
```

### Alternative File Access Methods

1. **Git**: Clone repositories directly in the container
   ```bash
   cd /home/claude/workspace
   git clone https://github.com/username/repo.git
   ```

2. **Volume mounts**: If you need more direct access, modify the deployment to mount additional host paths (for supported Kubernetes setups)

## Customization Options

### Modifying Resource Limits

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

### Persistence and Data Storage

The deployment uses persistent volume claims for:
- Config storage: `/home/claude/.config/claude-code`
- Workspace: `/home/claude/workspace`

If your cluster doesn't support dynamic provisioning, you may need to create persistent volumes manually.

## Troubleshooting

### Common Issues

1. **Claude command not found**:
   - Check if Node.js and npm were installed correctly
   - Verify PATH includes npm global bin directory

2. **Authentication failures**:
   - Ensure you have an active Anthropic account
   - Check network connectivity from the container

3. **Permission errors**:
   - The container runs as a non-root user for security
   - Check if volume mounts have correct permissions

### Viewing Logs

```bash
# Container logs
kubectl logs -n claude-code <pod-name>

# Claude Code logs (from inside the container)
cat /home/claude/.config/claude-code/logs/*
```

## Security Considerations

This containerized approach provides several security advantages:
- Isolates Claude Code from your host system
- Runs as a non-root user inside the container
- Uses Kubernetes abstractions for security boundaries

## License

This project is licensed under the MIT License - see the LICENSE file for details.

Claude Code itself is a product of Anthropic and subject to Anthropic's terms of service. This project provides containerization and deployment scripts only, and does not modify or redistribute Claude Code itself.
