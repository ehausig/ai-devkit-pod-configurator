# Creating Components

This guide explains how to create custom components for the AI DevKit Pod Configurator.

## Component Structure

Each component consists of:

1. **YAML Definition File** (required) - `components/CATEGORY/NAME.yaml`
2. **Documentation File** (recommended) - `components/CATEGORY/NAME.md`
3. **Pre-build Script** (optional) - `components/CATEGORY/NAME/NAME-setup.sh`
4. **Supporting Files** (optional) - `components/CATEGORY/NAME/...`

## Component Categories

Components are organized into categories:

```
components/
├── agents/          # AI coding assistants
├── languages/       # Programming languages and runtimes
├── build-deploy/    # Build and dependency management tools  
├── tools/           # Development and testing tools
└── your-category/   # Create your own categories
```

### Creating a New Category

1. Create a directory under `components/`
2. Add `.category.yaml` for metadata:

```yaml
# components/your-category/.category.yaml
display_name: Your Category Name
description: What this category contains
order: 10  # Display order (lower numbers first)
```

## Component YAML Schema

### Basic Structure

```yaml
# components/languages/example.yaml
id: EXAMPLE_COMPONENT
name: Example Component
version: "1.0.0"  # Optional version
group: example-group
requires: []  # List of required groups
description: Brief description of the component
```

### Field Descriptions

- **id**: Unique identifier (UPPERCASE_WITH_UNDERSCORES)
- **name**: Display name shown in the TUI
- **version**: Component version (optional)
- **group**: Mutual exclusion group (only one per group can be selected)
- **requires**: Array of group names this component depends on
- **description**: Brief description for users

### Command Permissions (Claude Code Integration)

Components can define permissions for Claude Code:

```yaml
command_permissions:
  allow:
    - "Bash(npm:*)"
    - "Bash(node:*)"
    - "Bash(npx:*)"
    - "Read(*.js)"
    - "Write(*.json)"
  deny:
    - "Bash(rm -rf:*)"
```

These permissions are aggregated across all selected components and injected into Claude Code's configuration.

### Installation Instructions

```yaml
installation:
  dockerfile: |
    # Standard Dockerfile commands
    RUN apt-get update && apt-get install -y example-package
    
    # Set up paths
    ENV PATH="/opt/example/bin:$PATH"
    
    # Create configuration
    RUN echo "config" > /etc/example.conf
```

### Nexus Proxy Support

For components that download packages, add Nexus configuration:

```yaml
installation:
  dockerfile: |
    # Main installation commands
    RUN curl -o example.tar.gz https://example.com/download
  
  nexus_config: |
    # Commands that only run when Nexus is available
    if [ -n "$USE_NEXUS_APT" ]; then
        echo "Using Nexus proxy for downloads"
        # Configure package manager for Nexus
    fi
```

### File Injection

To copy files from the build context:

```yaml
inject_files:
  - source: config-template.json
    destination: /tmp/config-template.json
    permissions: 644
  - source: script.sh
    destination: /usr/local/bin/script.sh
    permissions: 755
```

**Note**: Source paths are relative to the build context (`.build-temp/`), not the component directory.

### Runtime Setup

For initialization that happens when the container starts:

```yaml
entrypoint_setup: |
  # This runs in entrypoint.sh during container startup
  echo "Setting up Example Component..."
  
  # Configure for the devuser
  if [ ! -f /home/devuser/.example/config ]; then
      mkdir -p /home/devuser/.example
      cp /tmp/config-template.json /home/devuser/.example/config.json
      chown -R devuser:devuser /home/devuser/.example
  fi
  
  # Add to bashrc
  if ! grep -q "example init" "$BASHRC"; then
      echo 'eval "$(example init bash)"' >> "$BASHRC"
  fi
```

### Pre-build Scripts

For complex setup tasks, reference a pre-build script:

```yaml
pre_build_script: example/example-setup.sh
```

The script path is relative to the component's YAML file location.

## Component Documentation

Components can include markdown documentation that enhances AI assistant capabilities.

### Purpose

Documentation files:
- Provide usage examples for AI assistants
- Document component-specific workflows
- Help AI assistants give accurate responses
- Get imported into Claude Code's context

### File Naming

Documentation must have the same base name as the YAML:
- Component: `python-3.11.yaml`
- Documentation: `python-3.11.md`

### Documentation Structure

```markdown
# components/languages/example.md

#### Example Component

**Getting Started**:
```bash
# Initialize a new project
example init my-project

# Run the example
example run
```

**Environment Setup**:
```bash
# Activate virtual environment
example venv activate

# Install dependencies
example install -r requirements.txt
```

**Common Tasks**:
- Build project: `example build`
- Run tests: `example test`
- Deploy: `example deploy`

**Configuration**:
- Config file: `~/.example/config.json`
- Environment: `EXAMPLE_HOME`

**Troubleshooting**:
- If X happens, try Y
- Check logs at: `~/.example/logs/`
```

### Documentation Integration

1. Documentation is copied to `.build-temp/docs/`
2. Referenced in Claude Code's component imports
3. Available via `@import` syntax in CLAUDE.md
4. Provides context for AI assistance

## Pre-build Scripts

Pre-build scripts handle complex setup tasks:

```bash
#!/bin/bash
# components/agents/example/example-setup.sh

# Standard arguments provided by build system
TEMP_DIR="$1"
SELECTED_IDS="$2"
SELECTED_NAMES="$3"
SELECTED_YAML_FILES="$4"
SCRIPT_DIR="$5"

# Your setup logic
echo "Preparing Example Component..."

# Copy files to temp directory
cp -r "$SCRIPT_DIR/example/templates" "$TEMP_DIR/"

# Generate dynamic content
cat > "$TEMP_DIR/config.json" << EOF
{
  "components": "$SELECTED_NAMES",
  "generated": "$(date)"
}
EOF

# Process other components if needed
for yaml_file in $SELECTED_YAML_FILES; do
    echo "Processing: $yaml_file"
done

echo "Example Component prepared successfully"
```

### Pre-build Script Capabilities

- Generate configuration files
- Process selected components
- Aggregate permissions
- Create documentation
- Set up directory structures
- Download resources

## Component Dependencies

### Simple Dependencies

Component requires another group:

```yaml
requires: [nodejs]  # Requires any Node.js version
```

### Multiple Dependencies

```yaml
requires: [nodejs, build-tools]  # Requires Node.js AND build tools
```

### Mutual Exclusion

Components in the same group are mutually exclusive:

```yaml
# Only one Python version can be selected
group: python-version
```

## Real-World Example: Node.js Component

```yaml
# components/languages/nodejs-22.yaml
id: NODEJS_22
name: Node.js 22.x
version: "22.11.0"
group: nodejs
requires: []
description: Node.js 22.x - Latest features (non-LTS)
command_permissions:
  allow:
    - "Bash(node:*)"
    - "Bash(npm:*)"
    - "Bash(npx:*)"
    - "Bash(yarn:*)"
    - "Bash(pnpm:*)"
    - "Bash(bun:*)"
installation:
  dockerfile: |
    RUN export DEBIAN_FRONTEND=noninteractive && \
        ARCH=$(dpkg --print-architecture) && \
        NODE_ARCH=${ARCH} && \
        if [ "${ARCH}" = "arm64" ]; then NODE_ARCH="arm64"; elif [ "${ARCH}" = "amd64" ]; then NODE_ARCH="x64"; fi && \
        NODE_VERSION="v22.11.0" && \
        wget -q https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz && \
        tar -xJf node-${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz -C /usr/local --strip-components=1 && \
        rm node-${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz && \
        npm install -g npm@latest
  nexus_config: |
    if [ -n "$NPM_REGISTRY" ]; then \
        npm config set registry ${NPM_REGISTRY} && \
        echo "✓ Configured npm to use proxy" ; \
    fi
  test_command: node --version && npm --version
entrypoint_setup: |
  # Node.js 22 specific setup
  echo "Setting up Node.js 22 environment..."
  
  # Set up user's npm configuration
  mkdir -p /home/devuser/.npm-global
  
  # Configure npm for the devuser if proxy URL is provided
  if [ -n "$NPM_REGISTRY" ]; then
      npm config set --location=global registry ${NPM_REGISTRY}
      # Also set it for the devuser
      su - devuser -c "npm config set registry ${NPM_REGISTRY}"
      echo "✓ Configured npm registry for devuser"
  fi
  
  # Add npm global bin to PATH if not already present
  if ! grep -q ".npm-global/bin" "$BASHRC" 2>/dev/null; then
      echo '' >> "$BASHRC"
      echo '# npm global packages' >> "$BASHRC"
      echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$BASHRC"
      echo 'export NPM_CONFIG_PREFIX="$HOME/.npm-global"' >> "$BASHRC"
  fi
```

## Best Practices

### 1. Component Design

- **Single Responsibility**: Each component should do one thing well
- **Clear Dependencies**: Explicitly declare all requirements
- **Proper Grouping**: Use groups for mutually exclusive options
- **Documentation**: Always include usage documentation

### 2. Installation Best Practices

- Clean up package caches: `apt-get clean && rm -rf /var/lib/apt/lists/*`
- Use specific versions for reproducibility
- Handle both ARM64 and AMD64 architectures
- Test installation commands in isolation

### 3. Permission Design

- Grant minimal necessary permissions
- Use wildcards appropriately: `Bash(npm:*)` not `Bash(*)`
- Document why permissions are needed
- Consider security implications

### 4. Pre-build Scripts

- Make scripts idempotent
- Handle errors gracefully
- Log progress for debugging
- Clean up temporary files

### 5. Documentation

- Focus on practical examples
- Include common workflows
- Document configuration files
- Provide troubleshooting tips

## Testing Components

### Local Testing

1. Run the build with only your component:
   ```bash
   ./build-and-deploy.sh
   # Select only your component
   ```

2. Verify installation:
   ```bash
   kubectl exec -it -n ai-devkit deployment/ai-devkit -- bash
   # Test your component inside the container
   ```

3. Check logs:
   ```bash
   tail -f build-and-deploy.log
   ```

### Validation Checklist

- [ ] YAML syntax is valid
- [ ] Component appears in TUI
- [ ] Dependencies resolve correctly
- [ ] Installation completes successfully
- [ ] Runtime setup works
- [ ] Documentation is helpful
- [ ] Permissions are appropriate

## Troubleshooting

### Component Not Appearing

1. Check YAML syntax with `yq`:
   ```bash
   yq eval . components/CATEGORY/component.yaml
   ```

2. Verify required fields:
   - id, name, group, description

3. Check category structure:
   - Component in correct directory
   - Category has valid name

### Installation Failures

1. Test Dockerfile commands:
   ```bash
   docker run -it ubuntu:22.04 bash
   # Run installation commands manually
   ```

2. Check architecture compatibility:
   - Different download URLs for ARM64/AMD64?
   - Architecture detection working?

3. Verify network access:
   - Can download required files?
   - Proxy settings needed?

### Pre-build Script Issues

1. Run script manually:
   ```bash
   cd components/CATEGORY
   ./component-setup.sh /tmp/test "ID" "Name" "path.yaml" "$(pwd)"
   ```

2. Check permissions:
   ```bash
   chmod +x component-setup.sh
   ```

3. Debug with set -x:
   ```bash
   bash -x component-setup.sh
   ```

## Advanced Topics

### Complex Components

See the Claude Code component for an example of:
- Multiple sub-components (agents, commands, scripts)
- Dynamic configuration generation
- Permission aggregation
- Documentation system integration

### Component Composition

Components can:
- Depend on other components
- Share configuration via pre-build scripts
- Aggregate permissions and settings
- Build on each other's functionality

### Future Enhancements

Planned improvements:
- Component versioning and updates
- External component repositories
- Component marketplace
- Dependency version constraints
