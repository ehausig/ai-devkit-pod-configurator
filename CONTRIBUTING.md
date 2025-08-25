# Contributing to AI DevKit Pod Configurator

Thank you for your interest in contributing to AI DevKit Pod Configurator! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Component Development](#component-development)
- [Documentation](#documentation)
- [Community](#community)

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
3. **Create a feature branch** from `develop`
4. **Make your changes** with clear commits
5. **Push to your fork** and submit a pull request to `develop`

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- Clear, descriptive title
- Steps to reproduce the issue
- Expected vs actual behavior
- System information (OS, Kubernetes distribution, tool versions)
- Relevant logs or error messages
- Screenshots if applicable

### Suggesting Enhancements

Enhancement suggestions are welcome! Please:

- Use a clear, descriptive title
- Provide detailed description of the proposed feature
- Explain why this enhancement would be useful
- Include mockups or examples if applicable

### Contributing Code

1. **Find an issue** - Look for issues tagged `good first issue` or `help wanted`
2. **Comment on the issue** - Let others know you're working on it
3. **Follow the development workflow** - See [Developer Guide](docs/developer.md)
4. **Write tests** - Include tests for new functionality
5. **Update documentation** - Keep docs in sync with code changes

## Development Setup

### Prerequisites

```bash
# Required tools
brew install kubectl yq jq ssh-keygen     # macOS
sudo apt-get install kubectl yq jq openssh-client  # Ubuntu/Debian
sudo dnf install kubectl yq jq openssh-clients     # RHEL/Fedora

# Container runtime (choose one)
brew install docker                 # macOS with Docker Desktop
brew install colima                 # macOS with Colima
# OR install nerdctl for K3s
# OR install podman

# Kubernetes (choose one)
brew install colima                 # macOS recommended
# OR install K3s, minikube, kind, etc.

# Development tools
brew install shellcheck            # Shell script linting
```

### Local Development

```bash
# Clone and setup
git clone https://github.com/YOUR_USERNAME/ai-devkit-pod-configurator.git
cd ai-devkit-pod-configurator
git remote add upstream https://github.com/ehausig/ai-devkit-pod-configurator.git

# Create feature branch
git checkout develop
git pull upstream develop
git checkout -b feature/your-feature-name

# Make scripts executable
chmod +x *.sh

# Configure container runtime
./configure-container-runtime.sh

# Start development
./build-and-deploy.sh
```

## Coding Standards

### Bash Scripts

- Use `#!/bin/bash` shebang
- Set `set -e` for error handling
- Use UPPERCASE for global constants
- Use lowercase for local variables
- Always quote variables: `"$var"`
- Use meaningful function and variable names
- Add comments for complex logic

### YAML Files

- Use 2-space indentation
- Quote strings when necessary
- Follow component schema strictly
- Validate with `yq eval .`

### Documentation

- Use Markdown format
- Keep line length under 100 characters
- Include code examples
- Update relevant docs with code changes

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
```
feat(components): add Elixir language support
fix(tui): correct pagination on small terminals
docs(readme): update installation instructions
```

## Testing

### Component Testing

```bash
# Test your component
./build-and-deploy.sh
# Select only your component

# Verify inside container
kubectl exec -it -n ai-devkit deployment/ai-devkit -- bash
```

### Script Testing

```bash
# Lint scripts
shellcheck scripts/*.sh

# Test scripts
bash -x script.sh  # Debug mode
```

### TUI Testing

- Test all themes
- Test different terminal sizes
- Verify keyboard navigation
- Check error handling

## Submitting Changes

### Pull Request Process

1. **Update your branch**:
   ```bash
   git fetch upstream
   git rebase upstream/develop
   ```

2. **Create pull request**:
   - Target branch: `develop` (never `main`)
   - Clear title and description
   - Reference related issues
   - Include screenshots for UI changes

3. **PR Template**:
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation

   ## Testing
   - [ ] Tested locally
   - [ ] Tests pass
   - [ ] Docs updated

   ## Checklist
   - [ ] Code follows style guide
   - [ ] Self-reviewed
   - [ ] Commented complex code
   - [ ] No warnings generated
   ```

### Code Review

- Respond to feedback promptly
- Make requested changes
- Mark conversations as resolved
- Be respectful and professional

## Component Development

### Creating New Components

See [Creating Components](docs/components.md) for detailed guide.

Quick checklist:
- [ ] Valid YAML structure
- [ ] Meaningful ID and name
- [ ] Clear description
- [ ] Proper group assignment
- [ ] Dependencies declared
- [ ] Installation tested
- [ ] Documentation included
- [ ] Command permissions defined (if needed)

### Component Best Practices

- Single responsibility
- Architecture awareness (ARM64/AMD64)
- Clean up after installation
- Handle errors gracefully
- Document usage examples

## Documentation

### What to Document

- New features and components
- API changes
- Configuration options
- Usage examples
- Troubleshooting tips

### Documentation Standards

- Clear, concise writing
- Code examples that work
- Screenshots for UI features
- Proper markdown formatting
- Spell check before submitting

## Community

### Getting Help

- Check [documentation](docs/) first
- Search existing [issues](https://github.com/ehausig/ai-devkit-pod-configurator/issues)
- Ask in [discussions](https://github.com/ehausig/ai-devkit-pod-configurator/discussions)
- Be patient and respectful

### Becoming a Maintainer

Active contributors may be invited to become maintainers. Maintainers:
- Review and merge PRs
- Manage releases
- Guide project direction
- Support the community

## Recognition

Contributors are recognized in:
- Git history
- Release notes
- README acknowledgments
- Special thanks for significant contributions

## Thank You!

Your contributions make AI DevKit Pod Configurator better for everyone. Whether it's fixing a typo, adding a feature, or helping others, every contribution matters!

---

Questions? Open an issue or start a discussion. We're here to help!
