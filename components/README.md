# Components

This directory contains all the modular components that can be selected and combined to create customized development environments.

## 📁 Directory Structure

```
components/
├── agents/          # AI coding assistants (Claude Code, AI Kanban)
├── languages/       # Programming languages (Python, Go, Rust, etc.)
├── build-deploy/    # Build tools (Maven, Gradle, SBT)
├── tools/           # Development tools (TUI test framework)
└── .category.yaml   # Category metadata (in each category folder)
```

## 🔧 How Components Work

Each component is a self-contained unit that:
1. Defines what to install in the Docker image
2. Configures the runtime environment
3. Sets up user configurations
4. Manages dependencies and conflicts

Components are selected through the interactive TUI during `build-and-deploy.sh` and are combined to create a custom Docker image.

## 📝 Component Files

Each component consists of:

### Required Files
- **`component-name.yaml`** - Main component definition

### Optional Files
- **`component-name.md`** - Documentation for AI assistants
- **`component-name/`** - Directory with supporting files
  - **`component-name-setup.sh`** - Pre-build script
  - **`ai-devkit/`** - Configuration directory
    - **`config.yaml`** - Template configurations
    - **`file-mappings.yaml`** - File placement rules
    - **`repos.yaml`** - Repository configurations
    - **`tests/`** - Component verification tests

## 🎯 Component YAML Structure

```yaml
# Unique identifier (UPPERCASE_WITH_UNDERSCORES)
id: PYTHON_3_11

# Display name in TUI
name: Python 3.11

# Version (optional)
version: "3.11"

# Mutual exclusion group (only one per group can be selected)
group: python

# Required component groups
requires: []

# Brief description
description: Python 3.11 runtime with pip

# Docker installation commands
installation:
  dockerfile: |
    RUN apt-get update && apt-get install -y python3.11
    RUN ln -s /usr/bin/python3.11 /usr/bin/python

# Files to inject from build context
inject_files:
  - source: config.json
    destination: /tmp/config.json
    permissions: 644

# Runtime initialization (runs in entrypoint.sh)
entrypoint_setup: |
  echo "Setting up Python environment..."
  pip install --upgrade pip

# Pre-build script (optional)
pre_build_script: python-3.11/python-setup.sh

# Command permissions for Claude Code (optional)
command_permissions:
  allow:
    - "Bash(python:*)"
    - "Read(*.py)"
  deny:
    - "Bash(rm -rf:*)"
```

## ➕ Adding a New Component

### 1. Choose the Right Category

- **agents/** - AI assistants and automation tools
- **languages/** - Programming language runtimes
- **build-deploy/** - Build and dependency management
- **tools/** - Development utilities

### 2. Create Component YAML

```bash
# Create the component definition
vi components/languages/ruby-3.2.yaml
```

### 3. Define the Component

```yaml
id: RUBY_3_2
name: Ruby 3.2
group: ruby
description: Ruby 3.2 with bundler
installation:
  dockerfile: |
    RUN apt-get update && apt-get install -y ruby3.2 ruby3.2-dev
    RUN gem install bundler
```

### 4. Add Supporting Files (Optional)

```bash
# Create component directory
mkdir components/languages/ruby-3.2

# Add pre-build script
vi components/languages/ruby-3.2/ruby-setup.sh

# Add configuration templates
mkdir -p components/languages/ruby-3.2/ai-devkit
vi components/languages/ruby-3.2/ai-devkit/config.yaml
```

### 5. Add Tests (Optional but Encouraged)

Tests are optional but highly encouraged to verify component functionality.

#### Test Directory Structure
```bash
components/languages/ruby-3.2/ai-devkit/tests/
├── verify.sh              # Main verification script (recommended)
├── test-version.sh        # Version verification
├── test-installation.sh  # Installation verification
└── test-functionality.sh # Functional tests
```

#### Test Naming Conventions
- **Main test**: `verify.sh` - Primary verification script
- **Specific tests**: `test-*.sh` - Focused test scripts
- All test files must be executable (`chmod +x`)
- Test files are automatically prefixed with component ID during deployment

#### Test Script Template
```bash
#!/bin/bash
# Test: Ruby 3.2 Installation
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing Ruby 3.2 installation..."

# Version check
if ruby --version | grep -q "3.2"; then
    echo -e "${GREEN}✓${NC} Ruby version correct"
else
    echo -e "${RED}✗${NC} Ruby version incorrect"
    exit 1
fi

# Package manager check
if gem --version > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Gem available"
else
    echo -e "${RED}✗${NC} Gem not found"
    exit 1
fi

# Bundler check
if bundler --version > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Bundler installed"
else
    echo -e "${RED}✗${NC} Bundler not found"
    exit 1
fi

echo -e "${GREEN}Ruby 3.2 verification complete!${NC}"
```

#### Test Execution
Tests are automatically:
1. Staged to `.build-temp/staging/tests/` during build
2. Prefixed with component ID (e.g., `ruby-3-2-verify.sh`)
3. Deployed to `${DEVUSER_HOME}/.ai-devkit/tests/` in container
4. Executable via the generated `run-all.sh` orchestrator

#### Test Best Practices
- Keep tests focused and fast
- Use clear pass/fail indicators
- Exit with non-zero on failure
- Include helpful error messages
- Test core functionality, not edge cases
- Avoid external dependencies in tests

### 6. Test Your Component

```bash
# Run build with your component
./build-and-deploy.sh
# Select your new component in the TUI
# Verify it builds and runs correctly
```

## ✏️ Modifying Components

### Updating Installation
Edit the `installation.dockerfile` section in the YAML file:
```yaml
installation:
  dockerfile: |
    # Add new packages or commands
    RUN apt-get install -y additional-package
```

### Changing Dependencies
Update the `requires` field to add or remove dependencies:
```yaml
requires: [nodejs, git]  # Now requires Node.js and Git
```

### Modifying Runtime Setup
Edit the `entrypoint_setup` section for runtime changes:
```yaml
entrypoint_setup: |
  # This runs when container starts
  export NEW_ENV_VAR="value"
```

## ❌ Removing Components

### 1. Remove Component Files
```bash
# Remove the YAML definition
rm components/category/component-name.yaml

# Remove supporting directory if it exists
rm -rf components/category/component-name/

# Remove documentation if it exists
rm components/category/component-name.md
```

### 2. Check for Dependencies
Search for components that might depend on the one you're removing:
```bash
grep -r "group-name" components/
```

### 3. Update Any References
If other components reference this one, update their `requires` fields.

## 🔄 Component Dependencies

### Mutual Exclusion Groups
Components in the same `group` are mutually exclusive:
```yaml
# Only one Python version can be selected
group: python
```

### Required Dependencies
Components can require other component groups:
```yaml
# This component needs Node.js
requires: [nodejs]
```

### Dependency Resolution
- The TUI automatically enables required dependencies
- Conflicts are detected and prevented
- Dependencies are shown visually in the selection interface

## 🧪 Testing Components

### Component Tests Location
```
components/category/component-name/ai-devkit/tests/
├── verify.sh           # Main verification script
├── run-all.sh         # Test runner
└── test-*.sh          # Individual test scripts
```

### Running Tests in Container
```bash
# After deployment, SSH into container
ssh -p 2222 devuser@localhost

# Run all component tests
~/.ai-devkit/tests/run-all.sh

# Run specific component test
~/.ai-devkit/tests/verify-python-3.11.sh
```

## 🎨 Component Categories

### Creating a New Category
```bash
# Create category directory
mkdir components/new-category

# Add category metadata
cat > components/new-category/.category.yaml <<EOF
display_name: New Category
description: Description of this category
order: 50  # Display order (lower = earlier)
EOF
```

## 📚 Best Practices

1. **Keep Components Focused** - One component should do one thing well
2. **Document Dependencies** - Clearly specify what your component needs
3. **Test Thoroughly** - Include verification tests
4. **Use Groups Wisely** - Group mutually exclusive components
5. **Follow Naming Conventions** - Use consistent naming patterns
6. **Minimize Image Size** - Clean up package caches in Dockerfile
7. **Security First** - Don't install unnecessary packages
8. **Version Explicitly** - Pin package versions when possible

## 🔍 Troubleshooting

### Component Not Showing in TUI
- Check YAML syntax: `yq eval . components/category/component.yaml`
- Ensure the file has `.yaml` extension
- Verify the category directory exists

### Build Failures
- Check Dockerfile syntax in `installation.dockerfile`
- Verify package names are correct
- Check for typos in package repositories

### Dependency Issues
- Ensure required groups exist
- Check for circular dependencies
- Verify group names match exactly

### Testing Failures
- Make scripts executable: `chmod +x verify.sh`
- Check script paths are correct
- Verify expected commands are installed

## 📖 Examples

See existing components for reference:
- **Simple Language**: `components/languages/python-3.11.yaml`
- **Complex Agent**: `components/agents/claude-code.yaml`
- **Build Tool**: `components/build-deploy/maven.yaml`
- **With Tests**: `components/agents/ai-kanban/`