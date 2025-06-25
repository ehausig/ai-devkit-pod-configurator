# Troubleshooting Guide

This guide covers common issues and their solutions when using the AI DevKit Pod Configurator.

## Table of Contents

- [Build Issues](#build-issues)
- [Deployment Issues](#deployment-issues)
- [Component Issues](#component-issues)
- [Connection Issues](#connection-issues)
- [Disk Space Issues](#disk-space-issues)
- [Git Configuration Issues](#git-configuration-issues)
- [Claude Code Issues](#claude-code-issues)
- [TUI Display Issues](#tui-display-issues)
- [Performance Issues](#performance-issues)
- [Debugging Tips](#debugging-tips)

## Build Issues

### Docker Build Fails

**Symptoms:**
- Build exits with error
- "Docker build failed" message

**Solutions:**

1. **Check the build log**:
   ```bash
   tail -100 build-and-deploy.log
   ```

2. **Verify Docker is running**:
   ```bash
   docker info
   ```

3. **Clear Docker cache**:
   ```bash
   docker system prune -a
   ```

4. **Check available disk space**:
   ```bash
   df -h
   ```

### Component Installation Fails

**Symptoms:**
- Specific component fails during build
- Package not found errors

**Solutions:**

1. **Check internet connectivity**:
   ```bash
   curl -I https://github.com
   ```

2. **Verify component YAML syntax**:
   ```bash
   # Look for syntax errors
   cat components/category/component.yaml
   ```

3. **Try building without the problematic component**

4. **If using Nexus proxy, verify it's accessible**:
   ```bash
   curl http://localhost:8081
   ```

## Deployment Issues

### Pod Stuck in Pending State

**Symptoms:**
- Pod never reaches Running state
- `kubectl get pods` shows Pending

**Solutions:**

1. **Check pod events**:
   ```bash
   kubectl describe pod -n ai-devkit <pod-name>
   ```

2. **Check for disk pressure** (common with Colima):
   ```bash
   kubectl get nodes -o wide
   ./cleanup-colima.sh
   ```

3. **Verify PVC creation**:
   ```bash
   kubectl get pvc -n ai-devkit
   ```

4. **Check resource limits**:
   ```bash
   kubectl top nodes
   ```

### Pod CrashLoopBackOff

**Symptoms:**
- Pod repeatedly restarts
- Status shows CrashLoopBackOff

**Solutions:**

1. **Check container logs**:
   ```bash
   kubectl logs -n ai-devkit <pod-name> -c ai-devkit
   kubectl logs -n ai-devkit <pod-name> -c ai-devkit --previous
   ```

2. **Verify entrypoint script**:
   ```bash
   # Check if entrypoint.sh was generated correctly
   ls -la .build-temp/entrypoint.sh
   ```

3. **Check for missing dependencies**:
   - Review selected components
   - Ensure all requirements are met

### Port Forwarding Fails

**Symptoms:**
- Cannot connect to SSH or Filebrowser
- "Connection refused" errors

**Solutions:**

1. **Kill existing port forwards**:
   ```bash
   pkill -f "kubectl.*port-forward.*ai-devkit"
   ```

2. **Restart port forwarding**:
   ```bash
   kubectl port-forward -n ai-devkit service/ai-devkit 2222:22 8090:8090
   ```

3. **Check service status**:
   ```bash
   kubectl get svc -n ai-devkit
   ```

## Component Issues

### Component Not Available for Selection

**Symptoms:**
- Component doesn't appear in TUI
- Category is missing

**Solutions:**

1. **Verify component files exist**:
   ```bash
   ls -la components/category/component.yaml
   ```

2. **Check category file**:
   ```bash
   cat components/category/.category.yaml
   ```

3. **Validate YAML syntax**:
   - Ensure proper indentation
   - Check for special characters
   - Verify all required fields

### Component Dependencies Not Met

**Symptoms:**
- Component shows "requires X" message
- Cannot select component

**Solutions:**

1. **Check requirements**:
   - Review the `requires:` field in component YAML
   - Select required components first

2. **Verify group names**:
   - Ensure dependency groups exist
   - Check for typos in group names

### Mutual Exclusion Conflicts

**Symptoms:**
- Selecting one component deselects another
- Components in same group conflict

**Solutions:**

1. **Review group assignments**:
   - Components in same `group:` are mutually exclusive
   - Choose only one per group

2. **Check if you need multiple versions**:
   - Consider if you really need multiple Python/Java versions
   - Use containers for isolation if needed

## Connection Issues

### SSH Connection Refused

**Symptoms:**
- `ssh devuser@localhost -p 2222` fails
- "Connection refused" error

**Solutions:**

1. **Verify SSH is running in container**:
   ```bash
   kubectl exec -n ai-devkit <pod-name> -- ps aux | grep sshd
   ```

2. **Check SSH host keys**:
   ```bash
   kubectl get secret ssh-host-keys -n ai-devkit
   ```

3. **Restart the pod**:
   ```bash
   kubectl delete pod -n ai-devkit <pod-name>
   ```

### Filebrowser Not Accessible

**Symptoms:**
- Cannot access http://localhost:8090
- Page doesn't load

**Solutions:**

1. **Check Filebrowser container**:
   ```bash
   kubectl logs -n ai-devkit <pod-name> -c filebrowser
   ```

2. **Verify port forwarding**:
   ```bash
   lsof -i :8090
   ```

3. **Try direct pod port-forward**:
   ```bash
   kubectl port-forward -n ai-devkit pod/<pod-name> 8090:8090
   ```

## Disk Space Issues

### Colima Disk Full

**Symptoms:**
- Build fails with "No space left on device"
- Kubernetes reports disk pressure

**Solutions:**

1. **Run cleanup script**:
   ```bash
   ./cleanup-colima.sh --force
   ```

2. **Check Docker images**:
   ```bash
   colima ssh -- docker images
   colima ssh -- docker system df
   ```

3. **Increase Colima disk size**:
   ```bash
   colima stop
   colima delete
   colima start --disk 100 --kubernetes
   ```

### Overlay2 Growth

**Symptoms:**
- `/var/lib/docker/overlay2` consuming excessive space
- Orphaned directories accumulating

**Solutions:**

1. **Check for orphaned directories**:
   ```bash
   ./cleanup-colima.sh --check
   ```

2. **Clean Docker system**:
   ```bash
   colima ssh -- docker system prune -a --volumes
   ```

3. **Restart Colima** (nuclear option):
   ```bash
   colima restart
   ```

## Git Configuration Issues

### Git Credentials Not Working

**Symptoms:**
- Git push/pull fails
- Authentication errors

**Solutions:**

1. **Reconfigure git on host**:
   ```bash
   ./configure-git-host.sh
   ```

2. **Check secret creation**:
   ```bash
   kubectl get secret git-config -n ai-devkit -o yaml
   ```

3. **Verify in container**:
   ```bash
   kubectl exec -it -n ai-devkit <pod-name> -- cat /home/devuser/.git-credentials
   ```

### GitHub CLI (gh) Authentication Fails

**Symptoms:**
- `gh auth status` shows not authenticated
- Cannot create repos or PRs

**Solutions:**

1. **Check gh config**:
   ```bash
   kubectl exec -it -n ai-devkit <pod-name> -- cat /home/devuser/.config/gh/hosts.yml
   ```

2. **Re-authenticate**:
   ```bash
   # Inside container
   gh auth login
   ```

## Claude Code Issues

### Claude Code Not Found

**Symptoms:**
- `claude` command not found
- Claude Code not available in container

**Solutions:**

1. **Verify Claude Code was selected**:
   - Claude Code is optional
   - Must be explicitly selected during build

2. **Check installation**:
   ```bash
   kubectl exec -it -n ai-devkit <pod-name> -- which claude
   ```

3. **Review build log**:
   ```bash
   grep -i "claude" build-and-deploy.log
   ```

### Claude Code Configuration Issues

**Symptoms:**
- Claude doesn't start properly
- Missing configuration files

**Solutions:**

1. **Check CLAUDE.md exists**:
   ```bash
   kubectl exec -it -n ai-devkit <pod-name> -- ls -la /home/devuser/.claude/
   ```

2. **Verify settings.json**:
   ```bash
   kubectl exec -it -n ai-devkit <pod-name> -- cat /home/devuser/.claude/settings.json
   ```

3. **Review memory content**:
   ```bash
   kubectl exec -it -n ai-devkit <pod-name> -- head -50 /home/devuser/.claude/CLAUDE.md
   ```

## TUI Display Issues

### Colors Not Showing

**Symptoms:**
- TUI appears monochrome
- No color differentiation

**Solutions:**

1. **Check TERM variable**:
   ```bash
   echo $TERM
   export TERM=xterm-256color
   ```

2. **Try different terminal**:
   - Use iTerm2 on macOS
   - Enable 24-bit color in terminal settings

3. **Use minimal theme**:
   ```bash
   AI_DEVKIT_THEME=minimal ./build-and-deploy.sh
   ```

### TUI Navigation Not Working

**Symptoms:**
- Arrow keys don't work
- Cannot select components

**Solutions:**

1. **Check terminal mode**:
   - Ensure not in vim mode
   - Try different terminal emulator

2. **Use alternative keys**:
   - j/k for up/down
   - h/l for left/right
   - SPACE for select

3. **Reset terminal**:
   ```bash
   reset
   stty sane
   ```

## Performance Issues

### Slow Build Times

**Symptoms:**
- Builds take excessive time
- Downloads are slow

**Solutions:**

1. **Use Nexus proxy** (if available):
   - Set up local Nexus repository
   - Configure proxy repositories

2. **Reuse Docker cache**:
   - Don't use `--no-cache` unless necessary
   - Order Dockerfile commands efficiently

3. **Reduce selected components**:
   - Only select what you need
   - Use minimal base for testing

### Container Performance

**Symptoms:**
- Container is slow or unresponsive
- High CPU/memory usage

**Solutions:**

1. **Check resource limits**:
   ```bash
   kubectl top pod -n ai-devkit
   ```

2. **Increase resources**:
   ```yaml
   # Edit kubernetes/deployment.yaml
   resources:
     limits:
       memory: "8Gi"
       cpu: "8000m"
   ```

3. **Monitor processes**:
   ```bash
   kubectl exec -it -n ai-devkit <pod-name> -- htop
   ```

## Debugging Tips

### Enable Verbose Logging

1. **Build script debug mode**:
   ```bash
   # Add to build-and-deploy.sh
   set -x  # Enable debug output
   ```

2. **Component script debugging**:
   ```bash
   # In pre-build scripts
   echo "DEBUG: Variable = $VARIABLE" >&2
   ```

### Check Temporary Files

```bash
# Build artifacts
ls -la .build-temp/

# Generated Dockerfile
cat .build-temp/Dockerfile

# Component imports
cat .build-temp/component-imports.txt
```

### Kubernetes Debugging

```bash
# Get all resources
kubectl get all -n ai-devkit

# Describe everything
kubectl describe all -n ai-devkit

# Check events
kubectl get events -n ai-devkit --sort-by='.lastTimestamp'

# Shell into container
kubectl exec -it -n ai-devkit <pod-name> -- /bin/bash
```

### Common Log Locations

- **Build log**: `build-and-deploy.log`
- **Container logs**: `kubectl logs -n ai-devkit <pod-name>`
- **System logs**: Inside container at `/var/log/`

### Getting Help

If you're still experiencing issues:

1. **Check existing issues**: GitHub Issues page
2. **Gather information**:
   - OS and Kubernetes version
   - Selected components
   - Error messages and logs
3. **Create detailed issue**: Include all relevant information

## Prevention Tips

1. **Regular Maintenance**:
   - Run cleanup scripts periodically
   - Update components regularly
   - Monitor disk usage

2. **Test Incrementally**:
   - Start with minimal components
   - Add components one at a time
   - Verify each addition works

3. **Keep Backups**:
   - Export working configurations
   - Document successful component combinations
   - Save working Dockerfiles
