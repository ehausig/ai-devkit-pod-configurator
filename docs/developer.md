# Developer Guide

This guide covers how to contribute code to the AI DevKit Pod Configurator project.

## Table of Contents

1. [Development Setup](#development-setup)
2. [Development Workflow](#development-workflow)
3. [Coding Standards](#coding-standards)
4. [Testing Requirements](#testing-requirements)
5. [Submitting Changes](#submitting-changes)

## Development Setup

### Fork and Clone the Repository

```bash
# Fork the repository on GitHub first, then:
git clone https://github.com/YOUR_USERNAME/ai-devkit-pod-configurator.git
cd ai-devkit-pod-configurator

# Add upstream remote
git remote add upstream https://github.com/ehausig/ai-devkit-pod-configurator.git

# Verify remotes
git remote -v
```

### Set Up Your Development Environment

```bash
# Ensure you're on the develop branch
git checkout develop

# Sync with upstream
git fetch upstream
git merge upstream/develop

# Make scripts executable
chmod +x *.sh scripts/*.sh

# Install development dependencies (if any)
# Currently, the project uses standard bash tooling
```

## Development Workflow

### 1. Always Start with a Fresh Branch

**Critical**: Always create feature branches from `develop`, never from `main`:

```bash
# Ensure your develop branch is up to date
git checkout develop
git fetch upstream
git merge upstream/develop

# Create a new feature branch
git checkout -b feat/your-feature-name

# For bug fixes:
git checkout -b fix/issue-description

# For documentation:
git checkout -b docs/what-you-are-documenting
```

### 2. Make Your Changes

Follow these principles:

- **One Feature Per Branch**: Keep changes focused
- **Atomic Commits**: Each commit should be a logical unit
- **Clear Messages**: Use conventional commit format (see below)

### 3. Commit Your Changes

We use [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format: <type>(<scope>): <subject>

# Examples:
git commit -m "feat(tui): add new matrix theme"
git commit -m "fix(docker): correct entrypoint permissions"
git commit -m "docs(readme): update installation instructions"
git commit -m "test(components): add unit tests for yaml parser"
```

**Commit Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, not CSS)
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Maintenance tasks
- `perf`: Performance improvements
- `ci`: CI/CD changes
- `build`: Build system changes

### 4. Keep Your Branch Updated

**Important**: Regularly sync with upstream to avoid conflicts:

```bash
# Periodically sync with upstream develop
git fetch upstream
git rebase upstream/develop

# If there are conflicts:
# 1. Resolve conflicts in your editor
# 2. Stage the resolved files
git add .
# 3. Continue the rebase
git rebase --continue
```

### 5. Push Your Branch

```bash
# First push
git push origin feat/your-feature-name

# After rebasing, you may need to force push
git push origin feat/your-feature-name --force-with-lease
```

## Coding Standards

### Bash Scripts

1. **Shebang**: Always use `#!/bin/bash`
2. **Set Options**: Use `set -e` for error handling
3. **Variables**: 
   - Use UPPERCASE for constants/globals
   - Use lowercase for local variables
   - Always quote variables: `"$var"`
4. **Functions**: 
   - Use descriptive names
   - Add comments for complex logic
5. **Error Handling**: 
   - Check command success
   - Provide meaningful error messages

Example:
```bash
#!/bin/bash
set -e

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="operation.log"

# Function with error handling
perform_operation() {
    local input_file="$1"
    
    if [[ ! -f "$input_file" ]]; then
        echo "Error: File not found: $input_file" >&2
        return 1
    fi
    
    # Process file
    process_file "$input_file" || {
        echo "Error: Failed to process $input_file" >&2
        return 1
    }
}
```

### YAML Files

1. Use 2-space indentation
2. Quote strings when necessary
3. Add comments for clarity
4. Follow component schema strictly

### Documentation

1. Use Markdown for all docs
2. Include code examples
3. Keep line length under 100 characters
4. Use proper heading hierarchy

## Testing Requirements

### 1. Component Testing

When adding new components:

```bash
# Test your component locally
./build-and-deploy.sh

# Verify the component installs correctly
kubectl exec -it -n ai-devkit deployment/ai-devkit -- bash
# Inside container: verify your component works
```

### 2. Script Testing

Before submitting:

```bash
# Run shellcheck on your scripts
shellcheck scripts/*.sh

# Test scripts work on both Linux and macOS
# Test with minimal dependencies
```

### 3. TUI Testing

For TUI changes:

```bash
# Test all themes
AI_DEVKIT_THEME=dark ./build-and-deploy.sh
AI_DEVKIT_THEME=matrix ./build-and-deploy.sh
# etc.

# Test navigation and selection
# Test error cases
```

## Submitting Changes

### 1. Create Pull Request

**Before creating a PR, ensure your branch is up to date**:

```bash
# One final sync with upstream
git fetch upstream
git rebase upstream/develop

# Push your branch
git push origin feat/your-feature-name
```

Then on GitHub:

1. Go to your fork
2. Click "Pull Request"
3. **Ensure base is `ehausig/ai-devkit-pod-configurator:develop`** (not main!)
4. Fill out the PR template:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested locally
- [ ] Tests pass
- [ ] Documentation updated

## Screenshots (if applicable)
Add screenshots for UI changes

## Checklist
- [ ] My code follows the project style
- [ ] I've added tests (if applicable)
- [ ] All tests pass
- [ ] My commits follow conventional format
- [ ] I've updated documentation
```

### 2. Respond to Reviews

- Address feedback promptly
- Push new commits (don't force push during review)
- Mark conversations as resolved when addressed
- Be respectful and professional

### 3. After Merge

Once your PR is merged:

```bash
# Clean up your local branch
git checkout develop
git pull upstream develop
git branch -d feat/your-feature-name

# Delete remote branch
git push origin --delete feat/your-feature-name
```

## Common Development Tasks

### Adding a New Component

1. Create YAML file in appropriate category directory
2. Add corresponding markdown documentation
3. Test the component thoroughly
4. Update relevant documentation

See [Creating Components](components.md) for detailed instructions.

### Modifying the TUI

1. Test all themes
2. Ensure keyboard navigation works
3. Test on different terminal sizes
4. Update screenshots if needed

### Updating Dependencies

1. Document why the update is needed
2. Test thoroughly
3. Update relevant documentation

## Getting Help

- Open an issue for bugs
- Use discussions for questions
- Check existing issues before creating new ones

## Next Steps

Once you're comfortable with development, consider reviewing the [Maintainer Guide](maintainer.md) to understand the full project lifecycle.
