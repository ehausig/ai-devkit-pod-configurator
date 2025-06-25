# Component System Documentation

The AI DevKit Pod Configurator uses a modular component system that allows you to build customized development environments with only the tools you need.

## Table of Contents

- [Component Structure](#component-structure)
- [Creating a New Component](#creating-a-new-component)
- [Component Categories](#component-categories)
- [YAML Schema](#yaml-schema)
- [Pre-build Scripts](#pre-build-scripts)
- [File Injection](#file-injection)
- [Testing Components](#testing-components)
- [Best Practices](#best-practices)

## Component Structure

Each component consists of:

1. **YAML Definition** (`component-name.yaml`) - Metadata and installation instructions
2. **Documentation** (`component-name.md`) - Optional markdown documentation
3. **Pre-build Script** (`component-setup.sh`) - Optional setup script
4. **Template Files** - Any configuration files to inject

### Directory Layout

```
components/
├── category-name/
│   ├── .category.yaml          # Category metadata
│   ├── component-name.yaml     # Component definition
│   ├── component-name.md       # Component documentation
│   ├── component-setup.sh      # Pre-build script (optional)
│   └── templates/              # Template files (optional)
```

## Creating a New Component

### Step 1: Choose or Create a Category

Categories group related components. Create a new category directory if needed:

```bash
mkdir -p components/my-category
```

Create `.category.yaml`:

```yaml
display_name: My Category
description: Description of what this category contains
order: 5  # Display order in the TUI (lower numbers appear first)
```

### Step 2: Create Component Definition

Create `components/my-category/my-component.yaml`:

```yaml
id: MY_COMPONENT
name: My Component
version: "1.0.0"
group: my-component-group  # For mutual exclusion
requires: dependency-group  # Space-separated list of required groups
description: Brief description of the component
pre_build_script: my-component-setup.sh  # Optional
installation:
  dockerfile: |
    # Dockerfile commands to install the component
    RUN apt-get update && \
        apt-get install -y my-package && \
        rm -rf /var/lib/apt/lists/*
  nexus_config: |
    # Optional: Commands for Nexus proxy configuration
    if [ -n "$USE_NEXUS_APT" ]; then
        # Configure for Nexus
    fi
  test_command: my-command --version
entrypoint_setup: |
  # Bash commands that run at container startup
  echo "Setting up My Component..."
  mkdir -p /home/devuser/.myconfig
```

### Step 3: Add Documentation (Optional)

Create `components/my-category/my-component.md`:

```markdown
#### My Component

**Quick Start**: Instructions for using the component

**Common Commands**:
- `command1` - Description
- `command2` - Description

**Tips and Tricks**:
- Useful information
- Best practices
```

### Step 4: Create Pre-build Script (Optional)

Pre-build scripts run during the Docker build process and can:
- Generate configuration files
- Process templates
- Copy files to the build directory

Create `components/my-category/my-component-setup.sh`:

```bash
#!/bin/bash
# Pre-build script for My Component

# Standard arguments provided
TEMP_DIR="$1"              # Build directory
SELECTED_IDS="$2"          # Space-separated selected component IDs
SELECTED_NAMES="$3"        # Space-separated selected component names
SELECTED_YAML_FILES="$4"   # Space-separated YAML file paths
SCRIPT_DIR="$5"            # Directory containing this script

# Generate configuration
cat > "$TEMP_DIR/my-config.json" << EOF
{
  "setting": "value"
}
EOF

# Copy templates
cp "$SCRIPT_DIR/templates/template.conf" "$TEMP_DIR/"

echo "My Component pre-build completed"
```

## Component Categories

### Built-in Categories

1. **AI Agents** (`agents/`) - AI assistants and coding companions
2. **Build & Deploy** (`build-tools/`) - Build automation tools
3. **Languages** (`languages/`) - Programming languages and runtimes

### Creating Custom Categories

You can create any category you need:

```bash
# Examples
components/databases/       # Database clients and tools
components/cloud/          # Cloud provider CLIs
components/devops/         # Infrastructure and DevOps tools
components/testing/        # Testing frameworks
components/editors/        # Text editors and IDEs
```

## YAML Schema

### Required Fields

- `id` - Unique identifier (uppercase with underscores)
- `name` - Display name in the TUI
- `group` - Mutual exclusion group
- `description` - Brief description
- `installation.dockerfile` - Installation commands

### Optional Fields

- `version` - Component version
- `requires` - Space-separated list of required groups
- `pre_build_script` - Script to run during build
- `installation.nexus_config` - Nexus proxy configuration
- `installation.test_command` - Command to verify installation
- `installation.inject_files` - Files to copy into the container
- `entrypoint_setup` - Commands to run at container startup
- `memory_content` - Documentation for AI agents (Claude Code)

### Mutual Exclusion Groups

Components in the same `group` are mutually exclusive. For example:

```yaml
# Only one Python version can be selected
group: python-version  # python-default, python-3.11, python-miniconda
group: java           # java-11-openjdk, java-17-adoptium, etc.
group: rust-version   # rust-stable, rust-nightly
```

### Dependencies

Use `requires` to specify dependencies:

```yaml
requires: java          # Requires any Java component
requires: nodejs-version python-version  # Requires both Node.js and Python
```

## Pre-build Scripts

Pre-build scripts are powerful tools for dynamic configuration:

### Use Cases

1. **Generate Configuration Files**
   ```bash
   # Generate config based on selected components
   if [[ "$SELECTED_IDS" == *"NODEJS"* ]]; then
       echo "node_modules/" >> "$TEMP_DIR/.gitignore"
   fi
   ```

2. **Process Templates**
   ```bash
   # Replace placeholders in templates
   sed "s/{{VERSION}}/$VERSION/g" "$SCRIPT_DIR/template.conf" > "$TEMP_DIR/config.conf"
   ```

3. **Copy Documentation**
   ```bash
   # Copy all markdown files for selected components
   for yaml_file in $SELECTED_YAML_FILES; do
       md_file="${yaml_file%.yaml}.md"
       [[ -f "$md_file" ]] && cp "$md_file" "$TEMP_DIR/"
   done
   ```

### Best Practices

- Always check if files exist before copying
- Use proper error handling
- Log actions for debugging
- Clean up temporary files
- Use the provided arguments instead of hardcoding paths

## File Injection

Components can inject configuration files into the container:

```yaml
installation:
  inject_files:
    - source: config.template
      destination: /home/devuser/.config/app/config.json
      permissions: 644
    - source: script.sh
      destination: /usr/local/bin/myscript
      permissions: 755
```

Files are copied from the component directory during build.

## Testing Components

### Local Testing

1. **Build with your component**:
   ```bash
   ./build-and-deploy.sh
   # Select your component in the TUI
   ```

2. **Verify installation**:
   ```bash
   kubectl exec -it -n ai-devkit <pod-name> -- su - devuser
   # Test your component's commands
   ```

3. **Check logs**:
   ```bash
   kubectl logs -n ai-devkit <pod-name>
   tail -f build-and-deploy.log
   ```

### Component Validation

Ensure your component:
- Installs successfully
- Doesn't conflict with other components
- Has proper documentation
- Includes a test command
- Handles errors gracefully

## Best Practices

### 1. Minimal Installation

- Only install what's necessary
- Clean up package manager caches
- Remove temporary files

```yaml
dockerfile: |
  RUN apt-get update && \
      apt-get install -y --no-install-recommends my-package && \
      rm -rf /var/lib/apt/lists/*
```

### 2. User Permissions

- Install to system locations as root
- Configure user-specific settings in `entrypoint_setup`
- Ensure proper file ownership

```yaml
entrypoint_setup: |
  mkdir -p /home/devuser/.myapp
  chown -R devuser:devuser /home/devuser/.myapp
```

### 3. Environment Variables

- Use existing environment variables when available
- Document any new environment variables
- Handle proxy configurations

```yaml
entrypoint_setup: |
  if [ -n "$PROXY_URL" ]; then
      echo "proxy=$PROXY_URL" >> /home/devuser/.myapp/config
  fi
```

### 4. Documentation

- Include practical examples
- Document common commands
- Provide troubleshooting tips
- Use consistent formatting

### 5. Error Handling

- Check if commands exist before using them
- Provide meaningful error messages
- Don't fail the entire build for optional features

```bash
if command -v mycommand &> /dev/null; then
    mycommand --init
else
    echo "Warning: mycommand not found, skipping initialization"
fi
```

### 6. Nexus Support

If your component downloads packages, add Nexus proxy support:

```yaml
nexus_config: |
  if [ -n "$USE_NEXUS_APT" ] && [ -n "$NEXUS_APT_URL" ]; then
      # Configure package manager to use Nexus
      echo "registry=$NEXUS_APT_URL/repository/npm-proxy/" > ~/.npmrc
  fi
```

## Examples

See the existing components for examples:

- `components/languages/python-miniconda.yaml` - Complex language installation
- `components/agents/claude-code.yaml` - AI agent with pre-build script
- `components/build-tools/gradle.yaml` - Build tool with Nexus support
- `components/languages/rust-stable.yaml` - Language with cargo configuration

## Contributing Components

1. Follow the structure and naming conventions
2. Test thoroughly in different configurations
3. Document all features and requirements
4. Submit a pull request with:
   - Component files
   - Updated README if adding a new category
   - Example usage in the PR description
