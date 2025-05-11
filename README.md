# Claude Code in Kubernetes

This project provides a containerized version of Claude Code running in Kubernetes, allowing you to use Anthropic's AI coding assistant in an isolated environment rather than directly on your host OS.

## Project Structure

```
claude-code-k8s/
├── Dockerfile              # Container definition for Claude Code
├── entrypoint.sh           # Container startup script
├── build-and-deploy.sh     # Helper script for building and deploying
├── kubernetes/
│   ├── namespace.yaml      # Kubernetes namespace definition
│   ├── pvc.yaml            # Persistent volume claims for configuration and workspace
│   └── deployment.yaml     # Deployment configuration
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

# Build and deploy
./build-and-deploy.sh

# Connect to the container
kubectl exec -it -n claude-code <pod-name> -- bash

# Inside the container, run Claude Code
cd /home/claude/workspace
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

# Building manually
docker build -t claude-code:latest .
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

# Connect to the pod
kubectl exec -it -n claude-code <pod-name> -- bash
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

## Working with Files

### Copying Files to/from the Container

Use `kubectl cp` to transfer files between your host and the container:

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

This project is provided as-is. Claude Code itself is subject to Anthropic's terms of service.
