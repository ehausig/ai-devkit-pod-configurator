#### Kubernetes Tools

A comprehensive suite of Kubernetes CLI tools for cluster management and operations.

**Installed Tools**:
- **kubectl (v1.34.1)** - Kubernetes command-line tool for cluster operations
- **helm (v3.19.0)** - Kubernetes package manager for deploying applications
- **k9s (v0.50.16)** - Terminal UI for managing Kubernetes clusters
- **kubectx (v0.9.5)** - Fast context switching between Kubernetes clusters
- **kubens (v0.9.5)** - Fast namespace switching for kubectl
- **stern (v1.33.1)** - Multi-pod and multi-container log tailing

**Initial Setup**:

Before using these tools, configure your kubeconfig:
```bash
configure-kubeconfig.sh
```

This interactive script helps you:
- Detect and configure K3s from host machine
- Set up remote Kubernetes cluster access
- Manage multiple cluster contexts

**kubectl - Kubernetes CLI**:
```bash
# View cluster info
kubectl cluster-info

# Get all resources in current namespace
kubectl get all

# Describe a resource
kubectl describe pod <pod-name>

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/bash

# View logs
kubectl logs <pod-name>

# Apply configuration
kubectl apply -f deployment.yaml

# Port forward
kubectl port-forward pod/<pod-name> 8080:80
```

**helm - Package Manager**:
```bash
# Add a chart repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repositories
helm repo update

# Search for charts
helm search repo nginx

# Install a chart
helm install my-release bitnami/nginx

# List installed releases
helm list

# Upgrade a release
helm upgrade my-release bitnami/nginx

# Uninstall a release
helm uninstall my-release

# Show chart values
helm show values bitnami/nginx
```

**k9s - Kubernetes TUI**:
```bash
# Launch k9s
k9s

# Launch in a specific namespace
k9s -n kube-system

# Launch with a specific context
k9s --context my-cluster
```

**k9s Navigation**:
- `:pod` - View pods
- `:svc` - View services
- `:deploy` - View deployments
- `:ns` - View namespaces
- `/` - Filter resources
- `d` - Describe resource
- `l` - View logs
- `e` - Edit resource
- `?` - Help

**kubectx - Context Switching**:
```bash
# List all contexts
kubectx

# Switch to a context
kubectx my-cluster

# Switch to previous context
kubectx -

# Rename a context
kubectx new-name=old-name

# Delete a context
kubectx -d context-name
```

**kubens - Namespace Switching**:
```bash
# List all namespaces
kubens

# Switch to a namespace
kubens kube-system

# Switch to previous namespace
kubens -
```

**stern - Log Tailing**:
```bash
# Tail logs from all pods in current namespace
stern .

# Tail logs from pods matching pattern
stern api

# Tail logs from specific namespace
stern . -n kube-system

# Tail logs with timestamp
stern . --timestamps

# Tail logs from multiple namespaces
stern . --all-namespaces

# Tail logs from containers matching pattern
stern . --container nginx

# Tail with color output
stern . --color always
```

**Common Workflows**:

1. **Connect to a new cluster**:
   ```bash
   configure-kubeconfig.sh
   kubectl config get-contexts
   kubectx <context-name>
   kubectl get nodes
   ```

2. **Deploy an application with Helm**:
   ```bash
   helm repo add my-repo https://charts.example.com
   helm repo update
   helm install my-app my-repo/app-chart
   kubectl get pods
   ```

3. **Debug application issues**:
   ```bash
   k9s  # Use TUI to explore cluster
   stern my-app  # Tail logs
   kubectl describe pod <pod-name>
   kubectl logs <pod-name>
   ```

4. **Manage multiple clusters**:
   ```bash
   kubectx  # List all contexts
   kubectx prod-cluster  # Switch to production
   kubens production  # Switch to production namespace
   kubectl get pods
   ```

**Configuration Files**:
- `~/.kube/config` - Kubernetes configuration with cluster contexts
- `~/.kubernetes-tools-readme.txt` - Quick reference guide

**Best Practices**:
- Always verify your current context before operations: `kubectl config current-context`
- Use `kubens` to avoid accidentally operating on wrong namespace
- Use `stern` for debugging across multiple pods
- Use `k9s` for visual cluster exploration
- Keep your kubeconfig organized with meaningful context names
