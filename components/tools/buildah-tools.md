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

After deployment, configure your container registries:

```bash
configure-buildah.sh
```

This interactive script will guide you through:
1. Adding registry URLs
2. Configuring TLS/HTTPS settings
3. Installing custom CA certificates
4. Setting up authentication (if required)
5. Testing registry connectivity

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

## Testing

Run the verification tests:

```bash
# Main verification
~/.ai-devkit/tests/buildah-tools-verify.sh

# Installation check
~/.ai-devkit/tests/buildah-tools-test-installation.sh

# Version check
~/.ai-devkit/tests/buildah-tools-test-version.sh

# Functionality test (builds a test image)
~/.ai-devkit/tests/buildah-tools-test-functionality.sh
```

## Complete Workflow Example

Here's a complete example of building and deploying a containerized application:

```bash
# 1. Configure registry (one-time setup)
configure-buildah.sh
# Add your k3s registry: registry.trucksim.svc.cluster.local:443

# 2. Create your application
cd ~/workspace
mkdir my-web-app && cd my-web-app

# 3. Create a Dockerfile
cat > Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EOF

# 4. Create content
echo "<h1>Hello from AI DevKit!</h1>" > index.html

# 5. Build the image
docker build -t my-web-app:latest .

# 6. Tag for your registry
docker tag my-web-app:latest registry.trucksim.svc.cluster.local:443/my-web-app:v1

# 7. Push to registry
docker push registry.trucksim.svc.cluster.local:443/my-web-app:v1

# 8. Verify it's in the registry
skopeo inspect docker://registry.trucksim.svc.cluster.local:443/my-web-app:v1

# 9. Deploy to Kubernetes (from host or kubectl)
kubectl create deployment my-web-app \
  --image=registry.trucksim.svc.cluster.local:443/my-web-app:v1
```

## Best Practices

1. **Use specific tags** - Avoid `:latest` in production
2. **Configure registries first** - Run `configure-buildah.sh` before building
3. **Use docker alias** - Most familiar for developers
4. **Clean up regularly** - Run `docker image prune` to save space
5. **Test locally first** - Use `docker run` to test before pushing
6. **Use multi-stage builds** - Reduce final image size
7. **Scan for vulnerabilities** - Use `skopeo` or external tools to scan images

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
