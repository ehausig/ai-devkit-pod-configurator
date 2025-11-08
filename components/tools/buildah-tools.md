# Buildah Container Build Tools

## Overview

The Buildah Tools component provides a complete rootless container image building solution for AI DevKit. It enables users to build, test, and push OCI/Docker container images from within their development environment without requiring Docker daemon or root privileges.

## Components Included

- **buildah** - Build OCI and Docker images without a daemon
- **podman** - Run and manage containers with Docker-compatible CLI
- **skopeo** - Inspect, copy, and manage container images
- **docker alias** - Convenience alias pointing to podman for familiar Docker experience

## Key Features

- ✅ **Rootless Operation** - Build and run containers without root privileges
- ✅ **No Daemon Required** - Direct image building without Docker daemon
- ✅ **Docker-Compatible** - Use familiar `docker` commands via alias
- ✅ **OCI Compliant** - Works with any OCI-compliant registry
- ✅ **Multi-Registry Support** - Configure multiple registries (k3s, Nexus, Docker Hub, etc.)
- ✅ **Custom CA Certificates** - Support for private registries with custom TLS
- ✅ **Persistent Storage** - Images and config persist across container restarts

## Installation

Select "Buildah Tools" in the AI DevKit component selection TUI under the "Tools" category.

## Initial Setup

### For Local Development (k3s)

**No setup required!** You can immediately start building and importing images:

```bash
# Build an image
podman build -t myapp:latest .

# Import to k3s
import-to-k8s-containerd.sh localhost/myapp:latest
```

### For Registry-Based Workflows (Nexus/Production)

Configure your container registries:

```bash
configure-buildah.sh
```

This interactive script will guide you through:
1. Adding registry URLs (Nexus, Harbor, internal registries, etc.)
2. Configuring TLS/HTTPS settings
3. Installing custom CA certificates
4. Setting up authentication (if required)
5. Testing registry connectivity

## Utilities Included

### import-to-k8s-containerd.sh

Imports images directly to k3s containerd for immediate use without a registry.

**Usage:**
```bash
import-to-k8s-containerd.sh <image-name:tag>
```

**Example:**
```bash
# Build an image
podman build -t myapp:v1.0 .

# Import to k3s containerd
import-to-k8s-containerd.sh localhost/myapp:v1.0

# Deploy (image is immediately available)
kubectl run myapp --image=localhost/myapp:v1.0 --image-pull-policy=Never
```

**How it works:**
- Exports image from podman to tar
- Transfers tar to k3s node via kubectl
- Imports into containerd's k8s.io namespace
- Verifies image is available
- Cleans up temporary resources

### configure-buildah.sh

Interactive registry configuration tool for setting up remote registries (Nexus, Harbor, etc.).

**Usage:**
```bash
# Interactive mode
configure-buildah.sh

# Quick add
configure-buildah.sh --add-registry

# Test existing registry
configure-buildah.sh --test registry.example.com:5000

# Show current config
configure-buildah.sh --show-config
```

### test-buildah-workflow.sh

Comprehensive test of the build → import → deploy workflow.

**Usage:**
```bash
test-buildah-workflow.sh
```

Verifies:
- podman/buildah installation
- Image building capability
- Containerd import to k3s
- Kubernetes deployment with local images
- Complete end-to-end workflow

## Registry Configuration

### Supported Registry Types

- **k3s Internal Registry** - `registry.namespace.svc.cluster.local:443`
- **Nexus Repository Manager** - `nexus.company.com:5000`
- **Docker Hub** - `docker.io` (default)
- **Private Registries** - Any OCI-compliant registry

### Example: Configure k3s Internal Registry

```bash
$ configure-buildah.sh

Choose an action:
  1) Add a new registry

Enter choice: 1

Registry URL: registry.trucksim.svc.cluster.local:443
Use TLS? [Y/n]: y
Skip TLS verification? [y/N]: n
Provide custom CA certificate? [y/N]: y

[Paste certificate content, press Ctrl+D when done]

✓ CA certificate installed
✓ Registry configured and tested successfully
```

### Example: Configure Nexus with Authentication

```bash
$ configure-buildah.sh --add-registry

Registry URL: nexus.company.com:5000
Use TLS? [Y/n]: y
Configure authentication? [y/N]: y
Username: developer
Password: ********

✓ Authentication configured
✓ Registry added
```

## Usage Examples

### Building Images

The `docker` alias makes Buildah/Podman feel just like Docker:

```bash
# Navigate to your project
cd ~/workspace/my-app

# Build with docker alias (actually using podman)
docker build -t my-app:latest .

# Or use podman directly
podman build -t my-app:latest .

# Or use buildah for more control
buildah bud -t my-app:latest .
```

### Tagging Images

```bash
# Tag for your registry
docker tag my-app:latest registry.example.com/my-app:v1.0

# Or with podman
podman tag my-app:latest registry.example.com/my-app:v1.0
```

### Pushing to Registry

```bash
# Push with docker alias
docker push registry.example.com/my-app:v1.0

# Or with podman
podman push registry.example.com/my-app:v1.0

# Or with buildah
buildah push my-app:latest docker://registry.example.com/my-app:v1.0
```

### Listing Images

```bash
docker images
# or
podman images
```

### Running Containers for Testing

```bash
# Run your built image
docker run -it my-app:latest

# Run with port mapping
docker run -p 8080:8080 my-app:latest

# Run with environment variables
docker run -e DATABASE_URL=postgres://... my-app:latest
```

## Advanced Usage

### Using Skopeo

Skopeo allows you to work with images without pulling them locally:

```bash
# Inspect a remote image
skopeo inspect docker://registry.example.com/my-app:latest

# Copy between registries
skopeo copy \
  docker://source.registry.com/image:tag \
  docker://dest.registry.com/image:tag

# Delete a remote image
skopeo delete docker://registry.example.com/my-app:old-tag

# List tags for an image
skopeo list-tags docker://registry.example.com/my-app
```

### Buildah Without Dockerfile

Buildah can build images without a Dockerfile:

```bash
# Create a container from base image
container=$(buildah from ubuntu:22.04)

# Run commands in the container
buildah run $container apt-get update
buildah run $container apt-get install -y nginx

# Copy files
buildah copy $container ./app /opt/app

# Configure the container
buildah config --entrypoint '/usr/sbin/nginx -g "daemon off;"' $container
buildah config --port 80 $container

# Commit to an image
buildah commit $container my-nginx:latest

# Cleanup
buildah rm $container
```

### Multi-Stage Builds

Just like Docker, you can use multi-stage builds:

```dockerfile
# Dockerfile
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN go build -o myapp

FROM alpine:latest
COPY --from=builder /app/myapp /usr/local/bin/
CMD ["myapp"]
```

```bash
docker build -t my-go-app:latest .
```

## Configuration Files

All configuration is stored in your home directory (persists across restarts):

- **`~/.config/containers/storage.conf`** - Storage configuration (rootless setup)
- **`~/.config/containers/registries.conf`** - Registry configuration
- **`~/.config/containers/auth.json`** - Registry authentication
- **`~/.config/containers/policy.json`** - Image signature policies
- **`~/.config/containers/certs.d/`** - Custom CA certificates per registry
- **`~/.local/share/containers/storage/`** - Image storage location

## Kubernetes Considerations

### Pod Requirements

For rootless container building to work in Kubernetes, the AI DevKit pod should have:

```yaml
securityContext:
  capabilities:
    add:
      - SYS_ADMIN  # Required for user namespaces
```

The AI DevKit deployment already includes these settings.

### Storage

Built images are stored in `~/.local/share/containers/storage/`, which is part of the persistent volume. This means:
- Images persist across pod restarts
- You can build once and push multiple times
- Storage usage counts against your PVC quota

## Troubleshooting

### Registry Connection Issues

```bash
# Test registry connectivity
configure-buildah.sh --test registry.example.com:443

# Check registry configuration
configure-buildah.sh --show-config

# List configured registries
configure-buildah.sh --list
```

### TLS Certificate Issues

If you see TLS errors:

```bash
# For testing, you can skip verification (not recommended for production)
podman push --tls-verify=false registry.example.com/image:tag

# Better: Install the CA certificate
configure-buildah.sh --add-registry
# Follow prompts to add CA certificate
```

### Authentication Issues

```bash
# Check current authentication
cat ~/.config/containers/auth.json

# Re-login to a registry
podman login registry.example.com
```

### Storage Issues

```bash
# Check storage usage
podman system df

# Clean up unused images
podman image prune -a

# Remove all images (careful!)
podman rmi --all
```

### Permission Issues

If you see permission errors, verify rootless setup:

```bash
# Check subuid/subgid configuration
grep $(whoami) /etc/subuid
grep $(whoami) /etc/subgid

# Should show: username:100000:65536
```

## Image Distribution Workflows

Buildah-tools supports two workflows for distributing images to Kubernetes:

### Workflow 1: Direct Containerd Import (Recommended for k3s/local)

**Best for:** Local development, k3s clusters, single-node clusters

This workflow imports images directly into containerd on the k3s node, matching the behavior of `nerdctl` when used directly on the k3s server. No registry configuration needed.

**Benefits:**
- ✅ No registry required
- ✅ No TLS/DNS configuration
- ✅ Images immediately available to kubelet
- ✅ Fastest workflow for local development
- ✅ Works offline

**Workflow:**

```bash
# 1. Build image with podman
podman build -t myapp:latest .

# 2. Import directly to k3s containerd
import-to-k8s-containerd.sh localhost/myapp:latest

# 3. Deploy with imagePullPolicy: Never
kubectl run myapp --image=localhost/myapp:latest --image-pull-policy=Never --restart=Never

# Or in a deployment YAML:
# apiVersion: v1
# kind: Pod
# metadata:
#   name: myapp
# spec:
#   containers:
#   - name: myapp
#     image: localhost/myapp:latest
#     imagePullPolicy: Never  # Use local containerd image
```

**How it works:**
1. Exports image from podman to tar file
2. Transfers tar to k3s node via kubectl
3. Imports into containerd's k8s.io namespace using `ctr`
4. Image is immediately available to kubelet

**Note:** Images imported this way are stored on the specific k3s node. For multi-node clusters, use the registry workflow instead.

### Workflow 2: Registry-Based (Recommended for production/teams)

**Best for:** Multi-node clusters, team collaboration, CI/CD pipelines, Nexus/Harbor deployments

This workflow pushes images to a container registry (Nexus, Harbor, internal registry, etc.), allowing any node in the cluster to pull the image.

**Benefits:**
- ✅ Works across multiple nodes
- ✅ Centralized image storage
- ✅ Team can share images
- ✅ Integrates with CI/CD
- ✅ Version management and history

**Workflow:**

```bash
# 1. Configure registry (one-time setup)
configure-buildah.sh

# 2. Build image
podman build -t myapp:latest .

# 3. Tag for registry
podman tag myapp:latest registry.example.com:5000/myapp:v1.0

# 4. Push to registry
podman push registry.example.com:5000/myapp:v1.0

# 5. Deploy to Kubernetes (image will be pulled from registry)
kubectl create deployment myapp --image=registry.example.com:5000/myapp:v1.0
```

### Which Workflow Should I Use?

| Use Case | Recommended Workflow |
|----------|---------------------|
| Local k3s development | ✅ Containerd Import |
| Single-node k3s cluster | ✅ Containerd Import |
| Quick iteration/testing | ✅ Containerd Import |
| Multi-node cluster | ✅ Registry-Based |
| Team collaboration | ✅ Registry-Based |
| Production deployment | ✅ Registry-Based |
| CI/CD pipeline | ✅ Registry-Based |
| Nexus/Harbor in use | ✅ Registry-Based |
| Offline development | ✅ Containerd Import |

## Testing

Run the comprehensive workflow test:

```bash
# Test complete build → import → deploy workflow
test-buildah-workflow.sh
```

This test will:
1. Verify podman/buildah are installed
2. Build a test image with podman
3. Import it to k3s containerd using import-to-k8s-containerd.sh
4. Deploy a pod that uses the local image (imagePullPolicy: Never)
5. Verify the pod runs successfully and shows expected output
6. Clean up all test resources

## Complete Workflow Examples

### Example 1: Local Development (Containerd Import)

Quick iteration for local k3s development:

```bash
# 1. Create your application
cd ~/workspace
mkdir my-web-app && cd my-web-app

# 2. Create a Dockerfile
cat > Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EOF

# 3. Create content
echo "<h1>Hello from AI DevKit!</h1>" > index.html

# 4. Build the image
podman build -t my-web-app:latest .

# 5. Import to k3s containerd
import-to-k8s-containerd.sh localhost/my-web-app:latest

# 6. Deploy to Kubernetes
kubectl run my-web-app \
  --image=localhost/my-web-app:latest \
  --image-pull-policy=Never \
  --port=80

# 7. Expose the pod
kubectl expose pod my-web-app --type=NodePort --port=80

# 8. Get the URL
kubectl get svc my-web-app
```

### Example 2: Registry-Based Deployment (Nexus/Production)

For team collaboration and production deployments:

```bash
# 1. Configure registry (one-time setup)
configure-buildah.sh
# Add your Nexus registry: nexus.company.com:5000

# 2. Create your application (same as above)
cd ~/workspace
mkdir my-web-app && cd my-web-app

cat > Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EOF

echo "<h1>Hello from AI DevKit!</h1>" > index.html

# 3. Build the image
podman build -t my-web-app:latest .

# 4. Tag for your registry
podman tag my-web-app:latest nexus.company.com:5000/my-web-app:v1.0

# 5. Push to registry
podman push nexus.company.com:5000/my-web-app:v1.0

# 6. Verify it's in the registry
skopeo inspect docker://nexus.company.com:5000/my-web-app:v1.0

# 7. Deploy to Kubernetes (any node can pull from registry)
kubectl create deployment my-web-app \
  --image=nexus.company.com:5000/my-web-app:v1.0 \
  --replicas=3

# 8. Expose the deployment
kubectl expose deployment my-web-app --type=LoadBalancer --port=80
```

## Best Practices

### General
1. **Use specific tags** - Avoid `:latest` in production, use semantic versions
2. **Clean up regularly** - Run `podman image prune` to save space
3. **Test locally first** - Use `podman run` to test before deploying
4. **Use multi-stage builds** - Reduce final image size
5. **Scan for vulnerabilities** - Use `skopeo inspect` or external tools

### For Containerd Import Workflow
1. **Use localhost/ prefix** - Tag images as `localhost/myapp:tag` for consistency
2. **Set imagePullPolicy: Never** - Always specify in pod specs to use local images
3. **Single-node only** - Don't use for multi-node clusters (image only on one node)
4. **Quick iteration** - Perfect for dev/test cycles, rebuild and re-import quickly

### For Registry-Based Workflow
1. **Configure registry first** - Run `configure-buildah.sh` before building
2. **Use full registry paths** - Always include registry URL in image tags
3. **Authenticate properly** - Use `podman login` for private registries
4. **Version your images** - Use tags like `v1.0.0`, `v1.0.1` for tracking
5. **Clean remote images** - Use `skopeo delete` to remove old versions from registry

## Documentation Resources

- **Buildah**: https://buildah.io
- **Podman**: https://podman.io
- **Skopeo**: https://github.com/containers/skopeo
- **OCI Specification**: https://opencontainers.org

## Security Notes

- All operations run as non-root user (devuser)
- Uses user namespaces for isolation
- No Docker daemon socket exposure
- TLS verification enforced by default
- Custom CA certificates supported
- Authentication stored securely in auth.json

## Support

For issues with:
- **Component installation**: Check AI DevKit logs
- **Registry configuration**: Run `configure-buildah.sh --show-config`
- **Build failures**: Check Dockerfile syntax and base image availability
- **Push failures**: Verify registry authentication and network connectivity
