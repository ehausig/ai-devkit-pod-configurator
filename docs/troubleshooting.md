# Troubleshooting Guide

This guide helps resolve common issues with the AI DevKit Pod Configurator.

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Build Failures](#build-failures)
3. [Deployment Issues](#deployment-issues)
4. [Connection Problems](#connection-problems)
5. [Component Issues](#component-issues)
6. [Performance Problems](#performance-problems)
7. [Known Issues](#known-issues)

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

### Cannot connect to Docker daemon

**Problem**: Docker commands fail with connection errors.

**Solution**:

For Colima:
```bash
# Check status
colima status

# Start if not running
colima start --kubernetes --cpu 4 --memory 8

# Verify Docker context
docker context use colima
```

For Linux:
```bash
# Check Docker service
sudo systemctl status docker

# Start if not running
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
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

# Or recursively
find . -name "*.sh" -type f -exec chmod +x {} \;
```

### Docker build fails

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
   
   # For Colima
   ./cleanup-colima.sh
   ```

3. **Network issues during build**:
   ```bash
   # Test connectivity
   curl -I https://registry-1.docker.io
   
   # Retry with no build cache
   docker build --no-cache -t ai-devkit:latest .
   ```

### Component installation fails

**Problem**: Specific component fails during Docker build.

**Solutions**:

1. **Check component YAML syntax**:
   ```bash
   # Validate YAML
   cat components/CATEGORY/component.yaml
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

2. **Check entrypoint script**:
   ```bash
   # Verify entrypoint exists and is executable
   kubectl exec -n ai-devkit deployment/ai-devkit -- ls -la /entrypoint.sh
   ```

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
   ```

3. **Verify SSH host keys**:
   ```bash
   # Check secret exists
   kubectl get secret ssh-host-keys -n ai-devkit
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

2. **Validate YAML**:
   ```bash
   # Check for syntax errors
   grep -E "^(id|name|group|requires):" components/CATEGORY/your-component.yaml
   ```

3. **Check for errors**:
   ```bash
   # Run with debug output
   bash -x ./build-and-deploy.sh 2>&1 | grep -i error
   ```

### Component conflicts not working

**Problem**: Multiple components from same group can be selected.

**Solution**:
- Verify all components in the group have exact same `group` value
- Check for typos or extra spaces in group names

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

2. **Use local Docker cache**:
   ```bash
   # Don't use --no-cache flag
   # Reuse layers when possible
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
   ```

3. **Adjust resource limits** in `kubernetes/deployment.yaml`

## Known Issues

### Critical Issues

#### Overlay2 Cleanup (Colima)

**Problem**: The `--overlay2` option in cleanup script corrupts Docker.

**Solution**: 
- **DO NOT USE** `./cleanup-colima.sh --overlay2`
- Use standard cleanup: `./cleanup-colima.sh`
- For severe issues: Delete and recreate Colima VM

### Platform Limitations

#### Limited Testing

**Tested Platforms**:
- ✅ macOS with Colima
- ⚠️  Linux with k3s (limited testing)
- ❌ Windows WSL2 (theoretical support only)
- ❌ Minikube (not tested)
- ❌ Kind (not tested)

#### Nexus Repository

**Limitations**:
- Only tested with local Nexus instances
- Remote Nexus not validated
- No testing without Nexus proxy

### Component Limitations

#### Mutual Exclusions

**Current State**:
- Simple group-based exclusions only
- No complex dependency resolution
- No version conflict handling

**Workaround**: Design components with clear groups

### Other Known Issues

1. **Repeated deployments may leave orphaned PVCs**
   ```bash
   # Clean up old PVCs
   kubectl delete pvc -n ai-devkit --all
   ```

2. **TUI rendering issues in some terminals**
   - Use supported terminal (iTerm2, GNOME Terminal, etc.)
   - Set `TERM=xterm-256color`

3. **Git configuration may need manual setup**
   - Run `./configure-git-host.sh` before first deployment

## Getting Help

If these solutions don't resolve your issue:

1. **Check the build log**:
   ```bash
   cat build-and-deploy.log
   ```

2. **Enable debug mode**:
   ```bash
   bash -x ./build-and-deploy.sh
   ```

3. **Search existing issues**:
   https://github.com/ehausig/ai-devkit-pod-configurator/issues

4. **Open a new issue** with:
   - Your platform (OS, Kubernetes distribution)
   - Complete error messages
   - Steps to reproduce
   - `build-and-deploy.log` contents

## Quick Fixes Checklist

- [ ] All scripts are executable (`chmod +x *.sh`)
- [ ] Kubernetes is running (`kubectl get nodes`)
- [ ] Docker/Colima is running (`docker ps`)
- [ ] Sufficient disk space (`df -h`)
- [ ] Sufficient memory allocated to Colima/VM
- [ ] No conflicting port forwards (`lsof -i :2222`)
- [ ] Component YAML files are valid
- [ ] Using a supported terminal emulator
