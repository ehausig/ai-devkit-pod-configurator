# Contributing to AI DevKit Pod Configurator

Thank you for your interest in contributing to AI DevKit Pod Configurator! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Contribution Guidelines](#contribution-guidelines)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Component Contributions](#component-contributions)
- [Documentation](#documentation)
- [Community](#community)

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please be respectful and inclusive in all interactions.

### Our Standards

- Be welcoming and inclusive
- Be respectful of differing viewpoints
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards others

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/yourusername/ai-devkit-pod-configurator.git
   cd ai-devkit-pod-configurator
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/ehausig/ai-devkit-pod-configurator.git
   ```
4. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## How to Contribute

### Types of Contributions

We welcome the following types of contributions:

1. **Bug Fixes**: Fix issues in existing code
2. **New Components**: Add support for new languages, tools, or AI agents
3. **Feature Enhancements**: Improve existing functionality
4. **Documentation**: Improve or add documentation
5. **Tests**: Add test coverage
6. **Themes**: Create new TUI themes
7. **Examples**: Provide usage examples

### Finding Issues to Work On

- Check the [Issues](https://github.com/ehausig/ai-devkit-pod-configurator/issues) page
- Look for issues labeled `good first issue` or `help wanted`
- Comment on an issue to claim it
- Create a new issue if you find a bug or have a feature idea

## Development Setup

### Prerequisites

- macOS, Linux, or WSL2 on Windows
- Kubernetes cluster (Colima, minikube, etc.)
- Docker or compatible runtime
- Git
- Basic shell scripting knowledge

### Local Development

1. **Set up your Kubernetes cluster**:
   ```bash
   # Example with Colima
   colima start --kubernetes --cpu 4 --memory 8
   ```

2. **Make scripts executable**:
   ```bash
   chmod +x *.sh
   ```

3. **Test your changes**:
   ```bash
   ./build-and-deploy.sh
   ```

## Contribution Guidelines

### Code Style

#### Shell Scripts

- Use Bash 3.2+ compatible syntax (for macOS compatibility)
- Follow these conventions:
  ```bash
  #!/bin/bash
  set -e  # Exit on error
  
  # Constants in UPPER_CASE
  readonly CONSTANT_VALUE="value"
  
  # Functions with descriptive names
  function_name() {
      local var=$1
      # Function body
  }
  
  # Main execution
  main() {
      # Main logic
  }
  
  main "$@"
  ```

- Use proper quoting:
  ```bash
  # Good
  VAR="$1"
  [[ -n "$VAR" ]] && echo "$VAR"
  
  # Bad
  VAR=$1
  [[ -n $VAR ]] && echo $VAR
  ```

#### YAML Files

- Use 2-space indentation
- Include all required fields
- Add helpful comments
- Follow this structure:
  ```yaml
  # Component description comment
  id: COMPONENT_ID
  name: Human Readable Name
  version: "1.0.0"
  group: component-group
  requires: dependency-groups
  description: Brief description
  installation:
    dockerfile: |
      # Installation commands
  ```

#### Markdown

- Use proper headings hierarchy
- Include code examples
- Add table of contents for long documents
- Follow standard Markdown conventions

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Maintenance tasks

Examples:
```
feat(components): add support for Deno runtime

fix(tui): correct pagination for large component lists

docs(readme): update installation instructions
```

## Testing

### Component Testing

1. **Build with your component**:
   ```bash
   ./build-and-deploy.sh
   # Select your component
   ```

2. **Verify installation**:
   ```bash
   kubectl exec -it -n ai-devkit <pod-name> -- su - devuser
   # Test component functionality
   ```

3. **Check all features work**:
   - Component installs correctly
   - Dependencies are resolved
   - Documentation is accessible
   - No conflicts with other components

### TUI Testing

1. **Test navigation**:
   - All keys work as expected
   - Pagination functions correctly
   - Selection/deselection works

2. **Test edge cases**:
   - Empty categories
   - Many components
   - Long component names
   - Dependency chains

### Build Process Testing

1. **Test different configurations**:
   - Minimal build (no components)
   - Full build (many components)
   - With/without Nexus proxy
   - With/without git configuration

2. **Error handling**:
   - Missing dependencies
   - Build failures
   - Network issues

## Pull Request Process

### Before Submitting

1. **Update your fork**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Test thoroughly**:
   - Run the build process
   - Verify your changes work
   - Check for regressions

3. **Update documentation**:
   - Add/update relevant docs
   - Update README if needed
   - Add inline comments for complex code

### Submitting a PR

1. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request**:
   - Go to GitHub and create a PR from your fork
   - Use a clear, descriptive title
   - Fill out the PR template completely
   - Link related issues with `Fixes #123`

3. **PR Description Template**:
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update

   ## Testing
   - [ ] Tested locally
   - [ ] Added tests
   - [ ] All tests pass

   ## Screenshots (if applicable)
   Add screenshots for UI changes

   ## Checklist
   - [ ] Code follows project style
   - [ ] Self-review completed
   - [ ] Documentation updated
   - [ ] No new warnings
   ```

### Review Process

1. **Automated Checks**: Ensure all CI checks pass
2. **Code Review**: Address reviewer feedback
3. **Updates**: Push additional commits as needed
4. **Merge**: Maintainer will merge when approved

## Component Contributions

### Adding a New Component

1. **Create component structure**:
   ```bash
   mkdir -p components/category/
   touch components/category/.category.yaml
   touch components/category/component.yaml
   touch components/category/component.md
   ```

2. **Define the component**:
   ```yaml
   # component.yaml
   id: MY_COMPONENT
   name: My Component
   version: "1.0.0"
   group: my-group
   requires: ""
   description: What this component does
   installation:
     dockerfile: |
       RUN apt-get update && \
           apt-get install -y my-package && \
           rm -rf /var/lib/apt/lists/*
   ```

3. **Add documentation**:
   ```markdown
   # component.md
   #### My Component

   **Quick Start**: How to use this component

   **Common Commands**:
   - `command1` - Description
   - `command2` - Description
   ```

4. **Test thoroughly**:
   - Build succeeds
   - Component installs
   - Features work
   - No conflicts

### Component Best Practices

1. **Minimize Size**:
   - Clean package caches
   - Remove unnecessary files
   - Use `--no-install-recommends`

2. **Handle Dependencies**:
   - Use `requires:` field correctly
   - Test with dependencies
   - Document requirements

3. **Support Nexus**:
   - Add `nexus_config:` section
   - Test with proxy enabled
   - Document proxy behavior

4. **Write Clear Documentation**:
   - Include examples
   - Explain common use cases
   - Provide troubleshooting tips

## Documentation

### Documentation Standards

1. **README Updates**:
   - Keep feature list current
   - Update examples
   - Maintain accuracy

2. **Component Docs**:
   - Use consistent format
   - Include version info
   - Provide examples

3. **Code Comments**:
   ```bash
   # Explain why, not what
   # BAD: Increment counter
   # GOOD: Track retry attempts for network resilience
   ((retry_count++))
   ```

### Documentation Checklist

- [ ] New features documented
- [ ] Examples provided
- [ ] Screenshots added (for UI changes)
- [ ] Troubleshooting section updated
- [ ] Architecture docs updated (if needed)

## Community

### Getting Help

- Open an issue for bugs
- Start a discussion for features
- Ask questions in issues with `question` label

### Reporting Bugs

Include:
1. **Environment**: OS, Kubernetes version
2. **Steps to reproduce**: Clear instructions
3. **Expected behavior**: What should happen
4. **Actual behavior**: What actually happens
5. **Logs**: Relevant error messages
6. **Screenshots**: If applicable

### Suggesting Features

1. **Check existing issues** first
2. **Describe the use case**: Why is this needed?
3. **Propose a solution**: How might it work?
4. **Consider alternatives**: Other approaches?

### Code Review Guidelines

As a reviewer:
- Be constructive and respectful
- Explain your suggestions
- Approve when satisfied
- Help new contributors

As a contributor:
- Be open to feedback
- Ask questions if unclear
- Update based on reviews
- Thank reviewers

## Recognition

Contributors are recognized in:
- Git history
- Release notes
- Contributors section
- Special thanks for significant contributions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

If you have questions about contributing:
1. Check existing documentation
2. Open an issue with the `question` label
3. Start a discussion

Thank you for contributing to AI DevKit Pod Configurator! 🎉
