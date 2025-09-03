# Init Container Architecture

## Overview
The AI DevKit Pod Configurator now uses an init container architecture to manage file distribution within Kubernetes pods. This replaces the previous complex volume mount system with a simpler, more reliable approach.

## How It Works

### Build Time
1. Components define their file requirements in `ai-devkit/file-mappings.yaml`
2. Build process stages all files in `.build-temp/staging/`
3. Manifest file (`manifest.txt`) is generated with copy instructions
4. Everything is packaged into ConfigMaps

### Deploy Time
1. Init container runs before main container
2. Reads manifest from ConfigMap
3. Copies each file to its destination
4. Sets appropriate permissions
5. Main container starts with all files in place

## Component Structure

```
components/languages/python-3.11/ai-devkit/
├── file-mappings.yaml    # Defines file destinations
├── config-templates/      # Templates for config generation
├── static/               # Static files (optional)
├── repos.yaml           # Default repositories
└── tests/               # Component tests
```

## File Mappings Format

```yaml
# file-mappings.yaml
files:
  # Generated configuration from template
  - source: generated/pip.conf
    dest: /home/devuser/.config/pip/pip.conf
    mode: "0644"
  
  # Static file
  - source: static/config.yaml
    dest: /home/devuser/.app/config.yaml
    mode: "0600"
  
  # Test file
  - source: tests/verify.sh
    dest: /home/devuser/.ai-devkit/tests/python-3-11-verify.sh
    mode: "0755"
```

## Manifest Format

The manifest uses a simple pipe-delimited format:
```
source|destination|mode|owner
generated/pip.conf|/home/devuser/.config/pip/pip.conf|0644|devuser
tests/verify.sh|/home/devuser/.ai-devkit/tests/verify.sh|0755|devuser
```

## Benefits

### Simplicity
- No complex volume mount logic
- Simple text-based manifest
- Easy to debug and trace

### Reliability
- Files copied exactly where specified
- No Kubernetes subPath issues
- No directory contamination

### Flexibility
- Support any destination path
- Mix of generated and static files
- Custom permissions per file

### Testing
- Test files properly isolated
- run-all.sh orchestrator included
- No double-prefixing issues

## Migration from volume-mounts.yaml

Components are automatically migrated from the old `volume-mounts.yaml` to `file-mappings.yaml`:

### Old Format (volume-mounts.yaml)
```yaml
mounts:
  - name: "pip-config"
    source: "pip.conf"
    target: "/home/devuser/.config/pip/pip.conf"
    type: "file"
```

### New Format (file-mappings.yaml)
```yaml
files:
  - source: generated/pip.conf
    dest: /home/devuser/.config/pip/pip.conf
    mode: "0644"
```

## Key Components

### Libraries
- `lib/file-mapping-manager.sh` - Processes file mappings and stages files
- `lib/generate-init-scripts-configmap.sh` - Creates init container script ConfigMap
- `lib/generate-dynamic-deployment.sh` - Includes init container in deployment

### Init Container
- Uses Alpine Linux base image
- Runs `/scripts/init-copy.sh` 
- Minimal resource requirements (32Mi memory, 10m CPU)
- Completes before main container starts

## Debugging

### Check Manifest
```bash
kubectl get configmap component-configs -n ai-devkit -o yaml | grep manifest.txt -A 20
```

### Check Init Container Logs
```bash
kubectl logs <pod-name> -c setup-configs -n ai-devkit
```

### Verify Files in Container
```bash
kubectl exec -it <pod-name> -n ai-devkit -- ls -la /home/devuser/.config/
kubectl exec -it <pod-name> -n ai-devkit -- ls -la /home/devuser/.ai-devkit/tests/
```

## Testing

Run the test plan to verify the init container architecture:
```bash
# Test 3.2: Component test injection
./build-and-deploy.sh --components PYTHON_3_11,NODEJS_20

# Verify tests are available
kubectl exec -it <pod-name> -n ai-devkit -- /home/devuser/.ai-devkit/tests/run-all.sh
```

## Future Enhancements

1. **Static File Support**: Components can add `ai-devkit/static/` directory for files that don't need template processing
2. **Root File Support**: Init container could run as root for system file placement
3. **Secret Integration**: Sensitive files could come from Kubernetes Secrets
4. **Validation**: Pre-flight checks to ensure all source files exist

## Compatibility

The system maintains compatibility with both yq versions:
- **kislyuk/yq** (Python-based): Uses jq syntax
- **mikefarah/yq** (Go-based): Uses eval syntax

Detection is automatic based on the yq binary type.