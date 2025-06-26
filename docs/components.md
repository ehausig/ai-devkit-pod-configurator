# Creating Components

This guide explains how to create custom components for the AI DevKit Pod Configurator.

## Component Structure

Each component consists of:

1. **YAML Definition File** (required) - `components/CATEGORY/NAME.yaml`
2. **Documentation File** (recommended) - `components/CATEGORY/NAME.md`
3. **Pre-build Script** (optional) - `components/CATEGORY/NAME-setup.sh`

## Component Categories

Components are organized into categories:

```
components/
├── agents/          # AI coding assistants
├── languages/       # Programming languages and runtimes
├── build-tools/     # Build and dependency management tools
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

## Component Documentation

Create a markdown file with the same name as your component:

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

**Configuration**:
- Config file: `~/.example/config.json`
- Environment: `EXAMPLE_HOME`

**Common Commands**:
```bash
example --version
example --help
```
```

## Pre-build Scripts

For complex setup tasks, create a pre-build script:

```bash
#!/bin/bash
# components/languages/example-setup.sh

# Standard arguments provided by build system
TEMP_DIR="$1"
SELECTED_IDS="$2"
SELECTED_NAMES="$3"
SELECTED_YAML_FILES="$4"
SCRIPT_DIR="$5"

# Your setup logic
echo "Preparing Example Component..."

# Copy files to temp directory
cp "$SCRIPT_DIR/example-config.json" "$TEMP_DIR/"

# Generate dynamic content
cat > "$TEMP_DIR/example-setup.txt" << EOF
Selected components: $SELECTED_NAMES
EOF

echo "Example Component prepared successfully"
```

## Component Dependencies

### Simple Dependencies

Component requires another group:

```yaml
requires: [python-version]  # Requires any Python version
```

### Multiple Dependencies

```yaml
requires: [python-version, build-tools]  # Requires Python AND build tools
```

### Mutual Exclusion

Components in the same group are mutually exclusive:

```yaml
# Only one Python version can be selected
group: python-version
```

## Best Practices

### 1. Naming Conventions

- **ID**: UPPERCASE_WITH_UNDERSCORES (e.g., `PYTHON_MINICONDA`)
- **Files**: lowercase-with-hyphens (e.g., `python-miniconda.yaml`)
- **Groups**: lowercase-with-hyphens (e.g., `python-version`)

### 2. Version Management

- Include version in the component name if multiple versions exist
- Use groups for mutual exclusion of versions
- Document version-specific features in the markdown

### 3. Installation Best Practices

- Clean up package manager caches (`apt-get clean`, `rm -rf /var/lib/apt/lists/*`)
- Verify installations with test commands
- Use specific versions when possible for reproducibility
- Handle both ARM64 and AMD64 architectures

### 4. Documentation

- Always include a markdown file with usage examples
- Document environment variables and configuration files
- Include troubleshooting tips
- Show common workflows

### 5. Testing

Test your component by:

1. Running the build script
2. Selecting only your component
3. Verifying it installs correctly
4. Testing all documented commands

## Example: Complete Python Component

```yaml
# components/languages/python-system.yaml
id: PYTHON_SYSTEM
name: Python (System)
version: "3.10"
group: python-version
requires: []
description: Python 3.10 from Ubuntu repositories
installation:
  dockerfile: |
    # Install Python from system packages
    RUN apt-get update && apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*
    
    # Create symbolic links
    RUN ln -sf /usr/bin/python3 /usr/bin/python && \
        ln -sf /usr/bin/pip3 /usr/bin/pip
  
  nexus_config: |
    # Configure pip to use Nexus if available
    if [ -n "$USE_NEXUS_APT" ] && [ -n "$PIP_INDEX_URL" ]; then
        pip config set global.index-url ${PIP_INDEX_URL}
        pip config set global.trusted-host ${PIP_TRUSTED_HOST}
    fi

entrypoint_setup: |
  # Configure pip for the devuser if proxy URL is provided
  if command -v python3 &> /dev/null && [ -n "$PIP_INDEX_URL" ]; then
      mkdir -p /home/devuser/.config/pip
      if [ ! -f /home/devuser/.config/pip/pip.conf ]; then
          echo "[global]" > /home/devuser/.config/pip/pip.conf
          echo "index-url = ${PIP_INDEX_URL}" >> /home/devuser/.config/pip/pip.conf
          echo "trusted-host = ${PIP_TRUSTED_HOST}" >> /home/devuser/.config/pip/pip.conf
          chown -R devuser:devuser /home/devuser/.config/pip
      fi
  fi
```

## Troubleshooting

### Component Not Showing in TUI

1. Check YAML syntax is valid
2. Ensure file is in correct category directory
3. Verify all required fields are present
4. Look for errors in build log

### Installation Fails

1. Test Dockerfile commands manually
2. Check for architecture-specific issues
3. Verify network connectivity for downloads
4. Review build output in `build-and-deploy.log`

### Dependencies Not Working

1. Verify group names match exactly
2. Check that required groups have available components
3. Test with simplified dependencies first
