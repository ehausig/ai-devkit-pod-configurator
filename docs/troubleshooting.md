# Troubleshooting Guide

This guide helps resolve common issues with the AI DevKit Pod Configurator.

## Table of Contents

1. [Prerequisites and Dependencies](#prerequisites-and-dependencies)
2. [Installation Issues](#installation-issues)
3. [Build Failures](#build-failures)
4. [Deployment Issues](#deployment-issues)
5. [Connection Problems](#connection-problems)
6. [Component Issues](#component-issues)
7. [Claude Code Issues](#claude-code-issues)
8. [Performance Problems](#performance-problems)
9. [Known Issues](#known-issues)

## Prerequisites and Dependencies

### Required Tools

The build system requires these tools:

```bash
# Check if all required tools are installed
which kubectl yq jq ssh-keygen

# Check configured container tool (from ~/.ai-devkit/config.yaml)
cat ~/.ai-devkit/config.yaml

# Install missing tools on macOS
brew install kubectl yq jq
# ssh-keygen is included with macOS

# Install on Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y curl openssh-client jq

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# yq (either version works)
# Option 1: mikefarah/yq (recommended)
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# Option 2: kislyuk/yq (Python-based, available in apt)
sudo apt-get install -y yq
```

### Configuration Not Found

**Problem**: Build fails with "Container runtime not configured"

**Solution**: Run the configuration script first:

```bash
./configure-container-runtime.sh
```

This will:
- Detect available container tools (docker, nerdctl, podman)
- Identify your Kubernetes runtime
- Save your preferences to `~/.ai-devkit/config.yaml`

### yq/jq Not Found

**Problem**: Build fails with "yq: command not found" or "jq: command not found"

**Solution**: The build system supports both versions of yq:

```bash
# macOS
brew install yq jq

# Linux - Option 1: mikefarah/yq (Go-based, recommended)
VERSION=v4.35.2  # Check for latest at https://github.com/mikefarah/yq/releases
BINARY=yq_linux_amd64
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY} -O /usr/bin/yq
chmod +x /usr/bin/yq

# Linux - Option 2: kislyuk/yq (Python-based, in apt/yum repos)
sudo apt-get install yq jq  # Debian/Ubuntu
sudo yum install yq jq      # RHEL/CentOS
```

## Installation Issues

### kubectl: command not found

**Problem**: The `kubectl` command is not available.

**Solution**:
```bash
# macOS
brew install kubectl

# Linux (snap)
sudo snap install kubectl --classic

# Linux (manual)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Configured tool not found

**Problem**: Build fails with "Configured tool 'nerdctl' is not installed"

**Solution**:

Either install the missing tool or reconfigure to use an available tool:

```bash
# Option 1: Install the missing tool (e.g., nerdctl)
wget https://github.com/containerd/nerdctl/releases/download/v1.7.2/nerdctl-1.7.2-linux-amd64.tar.gz
sudo tar -xzf nerdctl-1.7.2-linux-amd64.tar.gz -C /usr/local/bin

# Option 2: Reconfigure to use a different tool
./configure-container-runtime.sh
```

### Cannot connect to container tool

**Problem**: Docker/Podman/nerdctl commands fail with connection errors.

**Solution**:

For Docker with Colima:
```bash
# Check status
colima status

# Start if not running
colima start --kubernetes --cpu 4 --memory 8

# Verify Docker context
docker context use colima
```

For Linux with Docker:
```bash
# Check Docker service
sudo systemctl status docker

# Start if not running
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

For Linux with K3s:
```bash
# Check K3s service
sudo systemctl status k3s

# Start if not running
sudo systemctl start k3s

# Check kubeconfig
ls -la ~/.kube/config
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
```

### Kubernetes cluster unreachable

**Problem**: `kubectl` commands fail to connect.

**Solution**:
```bash
# Check cluster info
kubectl cluster-info

# For Colima
colima kubernetes status
colima start --kubernetes  # If not running

# For k3s
sudo systemctl status k3s
sudo systemctl start k3s

# Check kubeconfig
echo $KUBECONFIG
ls -la ~/.kube/config
```

## Build Failures

### Permission denied on scripts

**Problem**: Scripts fail with permission errors.

**Solution**:
```bash
# Make all scripts executable
chmod +x *.sh
chmod +x scripts/*.sh
chmod +x components/agents/claude-code/*.sh

# Or recursively
find . -name "*.sh" -type f -exec chmod +x {} \;
```

### Docker/Podman build fails

**Problem**: Container image fails to build.

**Solutions**:

1. **Check the log file**:
   ```bash
   tail -100 build-and-deploy.log
   ```

2. **Disk space issues**:
   ```bash
   # Check disk space
   df -h
   
   # Clean up Docker
   docker system prune -a
   
   # Clean up Podman
   podman system prune -a
   
   # For Colima
   ./cleanup-runtime.sh
   ```

3. **Network issues during build**:
   ```bash
   # Test connectivity
   curl -I https://registry-1.docker.io
   
   # Retry with no build cache (Docker)
   docker build --no-cache -t ai-devkit:latest .build-temp/
   
   # Retry with no build cache (Podman)
   podman build --no-cache -t ai-devkit:latest .build-temp/
   ```

### Image not available in K3s

**Problem**: Build succeeds but Kubernetes can't find the image.

**Explanation**: The solution depends on your container tool:
- **Podman**: Uses separate storage from K3s, requires image transfer
- **Docker**: Uses separate storage from K3s, requires image transfer  
- **nerdctl**: Shares containerd with K3s, no transfer needed!

**Recommended Setup for K3s**: Install nerdctl with buildkit for seamless integration:
```bash
# Install nerdctl and buildkit
wget https://github.com/containerd/nerdctl/releases/download/v1.7.2/nerdctl-1.7.2-linux-amd64.tar.gz
sudo tar -xzf nerdctl-1.7.2-linux-amd64.tar.gz -C /usr/local/bin

# Install buildkit
wget https://github.com/moby/buildkit/releases/download/v0.12.4/buildkit-v0.12.4.linux-amd64.tar.gz
sudo tar -xzf buildkit-v0.12.4.linux-amd64.tar.gz -C /usr/local

# Create docker alias for compatibility
sudo ln -s /usr/local/bin/nerdctl /usr/local/bin/docker

# Start buildkit
sudo systemctl start buildkit
```

**Solutions**:

1. **Check if image exists in Podman**:
   ```bash
   podman images | grep ai-devkit
   ```

2. **Check if image exists in K3s**:
   ```bash
   sudo k3s ctr -n k8s.io images list | grep ai-devkit
   ```

3. **Manual import if automatic import failed**:
   ```bash
   # Use the helper script
   ./import-image-to-k3s.sh ai-devkit:latest
   
   # Or manually:
   podman save ai-devkit:latest > /tmp/ai-devkit.tar
   sudo k3s ctr -n k8s.io images import /tmp/ai-devkit.tar
   rm /tmp/ai-devkit.tar
   ```

4. **Verify import succeeded**:
   ```bash
   sudo k3s ctr -n k8s.io images list | grep ai-devkit
   ```

5. **Check K3s namespace**:
   ```bash
   # List all namespaces
   sudo k3s ctr namespaces list
   
   # Check k8s.io namespace specifically
   sudo k3s ctr -n k8s.io images list
   ```

6. **If import keeps failing**:
   - Check sudo permissions: `sudo -v`
   - Check K3s is running: `sudo systemctl status k3s`
   - Check containerd socket: `sudo k3s ctr version`
   - Review detailed logs: `grep "image import" build-and-deploy.log`

### Component installation fails

**Problem**: Specific component fails during Docker build.

**Solutions**:

1. **Check component YAML syntax**:
   ```bash
   # Validate YAML
   yq eval . components/CATEGORY/component.yaml
   ```

2. **Test installation commands manually**:
   ```bash
   # Run a test container
   docker run -it ubuntu:22.04 bash
   # Try the installation commands
   ```

3. **Architecture issues**:
   - Ensure component supports both ARM64 and AMD64
   - Check for architecture-specific download URLs

### Missing files in container

**Problem**: Files that should be injected are not present (e.g., `/tmp/CLAUDE.md: No such file or directory`)

**Solution**: This was a bug in the refactored code where the Dockerfile was being overwritten:

1. **Check Dockerfile generation**:
   ```bash
   # Look for inject_files in the generated Dockerfile
   grep -A5 "inject_files" .build-temp/Dockerfile
   
   # Should see COPY commands, not placeholder
   # If you see "# INJECT_FILES_PLACEHOLDER", the injection failed
   ```

2. **Verify fix is applied**: Ensure `build_docker_image()` doesn't overwrite the Dockerfile:
   ```bash
   # This line should NOT exist in build_docker_image():
   # cp docker/Dockerfile.base "$TEMP_DIR/Dockerfile"
   ```

## Deployment Issues

### Pod stays in Pending state

**Problem**: Kubernetes pod never becomes ready.

**Solutions**:

1. **Check pod events**:
   ```bash
   kubectl describe pod -n ai-devkit
   kubectl get events -n ai-devkit
   ```

2. **Check PVC status**:
   ```bash
   kubectl get pvc -n ai-devkit
   # If pending, check storage class
   kubectl get storageclass
   ```

3. **Resource constraints**:
   ```bash
   # Check node resources
   kubectl top nodes
   kubectl describe nodes
   ```

### Pod crashes repeatedly

**Problem**: Pod enters CrashLoopBackOff state.

**Solutions**:

1. **Check logs**:
   ```bash
   kubectl logs -n ai-devkit deployment/ai-devkit
   kubectl logs -n ai-devkit deployment/ai-devkit --previous
   ```

2. **Common crash causes**:
   - Missing entrypoint.sh
   - File injection failed
   - Component setup error

3. **Debug with shell**:
   ```bash
   # Override entrypoint temporarily
   kubectl run debug --rm -it --image=ai-devkit:latest --command -- /bin/bash
   ```

## Connection Problems

### SSH connection refused

**Problem**: Cannot SSH to the container.

**Solutions**:

1. **Check port forwarding**:
   ```bash
   # Check if port-forward is running
   ps aux | grep "kubectl port-forward"
   
   # Restart port forwarding
   kubectl port-forward -n ai-devkit service/ai-devkit 2222:22 8090:8090 &
   ```

2. **Check SSH service**:
   ```bash
   # Check if SSH is running in container
   kubectl exec -n ai-devkit deployment/ai-devkit -- ps aux | grep sshd
   
   # Check SSH logs
   kubectl exec -n ai-devkit deployment/ai-devkit -- journalctl -u ssh
   ```

3. **Verify SSH host keys**:
   ```bash
   # Check secret exists
   kubectl get secret ssh-host-keys -n ai-devkit
   
   # If missing, regenerate
   ./build-and-deploy.sh
   ```

### Filebrowser not accessible

**Problem**: Cannot access web file manager.

**Solutions**:

1. **Check filebrowser container**:
   ```bash
   kubectl logs -n ai-devkit deployment/ai-devkit -c filebrowser
   ```

2. **Verify service**:
   ```bash
   kubectl get svc -n ai-devkit
   curl http://localhost:8090  # After port-forward
   ```

## Component Issues

### Component not showing in TUI

**Problem**: Created component doesn't appear in selector.

**Solutions**:

1. **Check file location**:
   ```bash
   # Ensure correct path
   ls -la components/CATEGORY/your-component.yaml
   ```

2. **Validate YAML with yq**:
   ```bash
   # Check for syntax errors
   yq eval . components/CATEGORY/your-component.yaml
   
   # Verify required fields
   yq eval '.id, .name, .group, .description' components/CATEGORY/your-component.yaml
   ```

3. **Check component loading**:
   ```bash
   # Enable debug output
   bash -x ./build-and-deploy.sh 2>&1 | grep -A5 "load_components"
   ```

### Component conflicts not working

**Problem**: Multiple components from same group can be selected.

**Solution**:
- Verify all components in the group have exact same `group` value
- Check for typos or extra spaces in group names
- Use yq to verify: `yq eval '.group' components/*/*.yaml | sort | uniq -c`

### Pre-build script not running

**Problem**: Component's pre-build script doesn't execute.

**Solutions**:

1. **Check script path**:
   ```yaml
   # In component YAML
   pre_build_script: component-dir/script.sh  # Relative to YAML file
   ```

2. **Verify script is executable**:
   ```bash
   chmod +x components/CATEGORY/*/script.sh
   ```

3. **Check script output**:
   ```bash
   # Pre-build output goes to build log
   grep -A10 "pre-build" build-and-deploy.log
   ```

## Claude Code Issues

### Claude Code not available

**Problem**: Claude command not found after deployment.

**Solutions**:

1. **Check installation**:
   ```bash
   kubectl exec -n ai-devkit deployment/ai-devkit -- which claude
   # Should show: /home/devuser/.npm-global/bin/claude
   ```

2. **Verify npm global path**:
   ```bash
   kubectl exec -n ai-devkit deployment/ai-devkit -- bash -c 'echo $PATH'
   # Should include: /home/devuser/.npm-global/bin
   ```

3. **Check Claude Code installation log**:
   ```bash
   grep -A20 "Claude Code" build-and-deploy.log
   ```

### Permission errors with Claude Code

**Problem**: Claude Code can't execute certain commands.

**Solutions**:

1. **Check aggregated permissions**:
   ```bash
   # Inside container
   cat ~/workspace/.claude/settings.local.json
   ```

2. **Verify component permissions**:
   ```bash
   # Check component YAML files
   yq eval '.command_permissions' components/*/*.yaml
   ```

3. **Add missing permissions** to component YAML:
   ```yaml
   command_permissions:
     allow:
       - "Bash(needed-command:*)"
   ```

### Agents not working

**Problem**: Claude Code agents not responding or delegating.

**Solutions**:

1. **Initialize system first**:
   ```bash
   # Create PROMPT.md
   echo "# Project: Test" > ~/workspace/PROMPT.md
   
   # Initialize
   /init-autonomous
   ```

2. **Check journal**:
   ```bash
   /show-journal
   # Look for NEXT_AGENT entries
   ```

3. **Verify agent files**:
   ```bash
   ls ~/.claude/agents/
   # Should show all agent .md files
   ```

## Performance Problems

### Slow package downloads

**Problem**: Build takes very long downloading packages.

**Solutions**:

1. **Enable Nexus proxy** (if available):
   ```bash
   # Start Nexus
   docker run -d -p 8081:8081 --name nexus sonatype/nexus3
   # Build script auto-detects Nexus
   ```

2. **Use Docker build cache**:
   ```bash
   # Don't clean everything
   # Selective cleanup preserves base layers
   docker image prune  # Instead of system prune -a
   ```

### Out of memory errors

**Problem**: Container or build fails with memory errors.

**Solutions**:

1. **Increase Colima resources**:
   ```bash
   colima stop
   colima start --kubernetes --cpu 6 --memory 12 --disk 100
   ```

2. **Check current usage**:
   ```bash
   kubectl top pods -n ai-devkit
   kubectl top nodes
   ```

3. **Adjust resource limits** in `kubernetes/deployment.yaml`

## Known Issues

### Critical Issues

#### Docker Corruption with cleanup-colima.sh

**Problem**: The `--overlay2` option corrupts Docker.

**Solution**: 
- **NEVER USE** `./cleanup-colima.sh --overlay2`
- Use standard cleanup: `./cleanup-colima.sh`
- For complete reset:
  ```bash
  colima delete
  colima start --kubernetes --cpu 4 --memory 8 --disk 100
  ```

### Platform Limitations

**Current Testing Status**:
- ✅ macOS with Colima (primary platform, fully supported)
- ✅ Linux with K3s (fully supported with runtime detection)
- ⚠️  Docker Desktop (supported, limited testing)
- ⚠️  Windows WSL2 (supported via runtime detection, limited testing)
- ⚠️  Minikube (supported via generic runtime, untested)
- ⚠️  Kind (supported via generic runtime, untested)

**Runtime Detection**: The system now automatically detects and adapts to your container runtime environment. All supported platforms use the same codebase with platform-specific optimizations.

### Component System Limitations

1. **Simple mutual exclusion only**
   - No complex dependency constraints
   - No version ranges
   - Workaround: Design clear component groups

2. **Pre-build script limitations**
   - Must handle own error checking
   - No automatic rollback
   - Workaround: Make scripts idempotent

### Other Known Issues

1. **PVC cleanup needed**:
   ```bash
   # Old PVCs may accumulate
   kubectl delete pvc -n ai-devkit --all
   ```

2. **Terminal compatibility**:
   - Some terminals may have rendering issues
   - Solution: Use iTerm2, GNOME Terminal, or Windows Terminal
   - Set: `export TERM=xterm-256color`

## Getting Help

If these solutions don't resolve your issue:

1. **Detailed diagnostics**:
   ```bash
   # Collect diagnostic information
   ./build-and-deploy.sh --version
   kubectl version --short
   docker version
   yq --version
   jq --version
   
   # Get detailed logs
   cat build-and-deploy.log
   kubectl describe all -n ai-devkit
   ```

2. **Enable debug mode**:
   ```bash
   # Run with bash debug output
   bash -x ./build-and-deploy.sh 2>&1 | tee debug.log
   ```

3. **Search existing issues**:
   https://github.com/ehausig/ai-devkit-pod-configurator/issues

4. **Open a new issue** with:
   - Your platform (OS, Kubernetes distribution)
   - Tool versions (kubectl, docker, yq, jq)
   - Complete error messages
   - Steps to reproduce
   - Relevant log excerpts

## Quick Fixes Checklist

Before diving deep into troubleshooting:

- [ ] All scripts are executable (`chmod +x *.sh`)
- [ ] Required tools installed (`yq`, `jq`, `kubectl`)
- [ ] Kubernetes is running (`kubectl get nodes`)
- [ ] Docker/Colima is running (`docker ps`)
- [ ] Sufficient disk space (`df -h`, min 20GB free)
- [ ] Sufficient memory allocated to VM (min 8GB)
- [ ] No conflicting port forwards (`lsof -i :2222`)
- [ ] Component YAML files are valid (`yq` parses them)
- [ ] Git configured if using git features (`./setup-container-git-credentials.sh`)
- [ ] Using a supported terminal emulator
- [ ] No spaces in project path

## Component Development Troubleshooting

### YAML Parsing Errors

**Problem**: Build fails with YAML parsing errors after refactoring to use `yq`.

**Solution**:
```bash
# Validate all component YAML files
for f in components/*/*.yaml; do
  echo "Checking $f"
  yq eval . "$f" > /dev/null || echo "ERROR in $f"
done
```

### Command Permissions Not Working

**Problem**: Claude Code permissions not properly aggregated.

**Debug steps**:
```bash
# Check generated permissions file
cat .build-temp/settings.local.json | jq .

# Verify component permissions are defined
yq eval '.command_permissions.allow' components/*/*.yaml

# Check pre-build script ran
grep -A5 "command permissions" build-and-deploy.log
```

### Inject Files Not Working

**Problem**: Files specified in inject_files not appearing in container.

**Debug steps**:
```bash
# Check if COPY commands were generated
grep "COPY.*tmp" .build-temp/Dockerfile

# Verify files exist in build context
ls -la .build-temp/

# Check inject_files processing
grep -B5 -A5 "inject_files" build-and-deploy.log
```

## Emergency Recovery

### Complete System Reset

If nothing else works:

```bash
# 1. Clean up Kubernetes
kubectl delete namespace ai-devkit

# 2. Clean up Docker
docker rmi ai-devkit:latest
docker system prune -a --volumes

# 3. For Colima users - full reset
colima delete
colima start --kubernetes --cpu 4 --memory 8 --disk 100

# 4. Re-clone repository
cd ..
rm -rf ai-devkit-pod-configurator
git clone https://github.com/ehausig/ai-devkit-pod-configurator.git
cd ai-devkit-pod-configurator

# 5. Start fresh
chmod +x *.sh
./build-and-deploy.sh
```

### Partial Recovery

For specific issues:

```bash
# Just rebuild image
docker rmi ai-devkit:latest
./build-and-deploy.sh

# Just redeploy to Kubernetes
kubectl delete deployment -n ai-devkit ai-devkit
kubectl apply -f kubernetes/

# Just restart port forwarding
pkill -f "kubectl port-forward"
kubectl port-forward -n ai-devkit service/ai-devkit 2222:22 8090:8090 &
```
