# Developer Workflow Guide

This guide walks you through the complete development workflow for the AI DevKit Pod Configurator project.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Commit Messages](#commit-messages)
- [Testing Your Changes](#testing-your-changes)
- [Release Process](#release-process)
- [Common Scenarios](#common-scenarios)
- [Troubleshooting](#troubleshooting)

## Quick Reference

```bash
# Start work on a new feature
git checkout develop && git pull
git checkout -b feat/your-feature-name
# ... make changes ...
git add .
git commit -m "feat: add your feature"
git push origin feat/your-feature-name
# Create PR to develop branch via GitHub

# After PR is merged, update local develop
git checkout develop
git pull origin develop
```

## Getting Started

### 1. Fork and Clone

```bash
# Fork the repository on GitHub first, then:
git clone https://github.com/YOUR_USERNAME/ai-devkit-pod-configurator.git
cd ai-devkit-pod-configurator

# Add upstream remote
git remote add upstream https://github.com/ehausig/ai-devkit-pod-configurator.git

# Verify remotes
git remote -v
```

### 2. Set Up Your Environment

```bash
# Make scripts executable
chmod +x *.sh
chmod +x scripts/*.sh

# Check current version
cat VERSION

# Ensure you're on develop branch
git checkout develop
git pull upstream develop
```

## Development Workflow

### Step 1: Create a Feature Branch

Always branch from `develop`, never from `main`:

```bash
# Update your local develop
git checkout develop
git pull upstream develop

# Create your feature branch
git checkout -b type/short-description

# Examples:
# git checkout -b feat/add-rust-support
# git checkout -b fix/docker-build-error
# git checkout -b docs/improve-readme
```

**Branch naming convention:**
- `feat/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation only
- `style/` - Code style changes
- `refactor/` - Code refactoring
- `test/` - Test additions/changes
- `chore/` - Maintenance tasks

### Step 2: Make Your Changes

```bash
# Example: Adding a new component
cd components/languages
create your-component.yaml
create your-component.md

# Test your changes locally
./build-and-deploy.sh
```

### Step 3: Commit Your Changes

We use [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Stage your changes
git add .

# Write a conventional commit message
git commit -m "type(scope): description

Longer explanation if needed

Fixes #123"
```

**Commit message examples:**
```bash
# Feature
git commit -m "feat(languages): add Rust 1.75 support"

# Bug fix
git commit -m "fix(docker): resolve build cache issue on ARM64"

# Documentation
git commit -m "docs: add troubleshooting guide for disk pressure"

# Breaking change (note the !)
git commit -m "feat!: change default Python version to 3.11"
```

### Step 4: Push and Create Pull Request

```bash
# Push your branch
git push origin feat/your-feature-name

# Create PR using GitHub CLI
gh pr create --base develop \
  --title "feat: add your feature" \
  --body "## Description
Brief description of your changes

## Type of Change
- [ ] Bug fix
- [x] New feature
- [ ] Breaking change
- [ ] Documentation

## Testing
- [x] Tested locally
- [x] All tests pass

## Screenshots (if applicable)
[Add screenshots]

Fixes #123"
```

Or create the PR via GitHub web interface - make sure to:
- Set base branch to `develop` (not main!)
- Fill out the PR template
- Link any related issues

### Step 5: After PR is Merged

```bash
# Update your local develop
git checkout develop
git pull upstream develop

# Delete your feature branch locally
git branch -d feat/your-feature-name

# Delete remote branch (if not auto-deleted)
git push origin --delete feat/your-feature-name
```

## Commit Messages

### Format

```
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```

### Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat: add Python 3.12 support` |
| `fix` | Bug fix | `fix: resolve memory leak in build script` |
| `docs` | Documentation | `docs: update installation guide` |
| `style` | Code style (formatting) | `style: fix indentation in yaml files` |
| `refactor` | Code refactoring | `refactor: simplify component loading` |
| `test` | Add/update tests | `test: add integration tests for TUI` |
| `chore` | Maintenance | `chore: update dependencies` |
| `perf` | Performance | `perf: optimize docker build cache` |
| `ci` | CI/CD changes | `ci: add GitHub Actions workflow` |

### Scope Examples

- `(components)` - Component system
- `(docker)` - Docker/container related
- `(k8s)` - Kubernetes related
- `(tui)` - Terminal UI
- `(languages)` - Language components
- `(agents)` - AI agent components

### Breaking Changes

Add `!` after type or include `BREAKING CHANGE:` in body:

```bash
# Method 1: Using !
git commit -m "feat!: remove support for Python 2.7"

# Method 2: In body
git commit -m "feat: update component API

BREAKING CHANGE: Component YAML schema now requires version field"
```

## Testing Your Changes

### 1. Local Testing

```bash
# Test the build process
./build-and-deploy.sh

# Select your components in the TUI
# Verify deployment succeeds

# Check the pod
kubectl get pods -n ai-devkit
kubectl logs -n ai-devkit <pod-name>

# SSH into container
ssh devuser@localhost -p 2222
```

### 2. Component Testing

If you added a new component:

```bash
# 1. Build with your component selected
# 2. Verify it installs correctly
# 3. Test its functionality
# 4. Check for conflicts with other components
# 5. Verify documentation is accessible
```

### 3. Clean Up

```bash
# After testing
kubectl delete namespace ai-devkit
./cleanup-colima.sh  # If using Colima
```

## Release Process

**Note:** Only maintainers can create releases, but understanding the process helps with contributions.

### 1. When is a Release Made?

Releases happen when:
- Significant features are complete
- Important bug fixes are ready
- Security updates are needed
- Monthly scheduled release (if changes exist)

### 2. Release Steps (for Maintainers)

```bash
# Create a release (interactive mode)
./scripts/create-release.sh

# Or specify the bump type directly
./scripts/create-release.sh patch  # Bug fixes
./scripts/create-release.sh minor  # New features
./scripts/create-release.sh major  # Breaking changes

# The script will:
# 1. Verify you're on develop branch
# 2. Calculate the new version automatically
# 3. Update VERSION file
# 4. Generate CHANGELOG
# 5. Create commits and PR
# 6. Generate a post-merge script for final steps
```

After the PR is merged, run the generated post-merge script:

```bash
# The script will be named: release-vX.Y.Z-post-merge.sh
./release-vX.Y.Z-post-merge.sh

# This will:
# 1. Tag the release
# 2. Push the tag
# 3. Create GitHub release
# 4. Merge main back to develop
# 5. Self-delete when complete
```

### 3. Version Numbering

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

Examples:
- `0.1.0` → `0.1.1` (patch): Fixed a bug in component loading
- `0.1.1` → `0.2.0` (minor): Added new Python component
- `0.2.0` → `1.0.0` (major): Changed component YAML schema

## Common Scenarios

### Scenario 1: Adding a New Language Component

```bash
# 1. Create branch
git checkout -b feat/add-elixir-support

# 2. Create component files
mkdir -p components/languages
cat > components/languages/elixir.yaml << 'EOF'
id: ELIXIR
name: Elixir
version: "1.15"
group: elixir-version
requires: ""
description: Elixir programming language
installation:
  dockerfile: |
    RUN apt-get update && \
        apt-get install -y elixir && \
        rm -rf /var/lib/apt/lists/*
EOF

# 3. Add documentation
cat > components/languages/elixir.md << 'EOF'
#### Elixir

**Quick Start**: `iex` for interactive shell
...
EOF

# 4. Test locally
./build-and-deploy.sh
# Select Elixir in TUI, verify it works

# 5. Commit and push
git add .
git commit -m "feat(languages): add Elixir 1.15 support

- Add Elixir component with apt installation
- Include interactive shell (iex) 
- Add quick start documentation"

git push origin feat/add-elixir-support

# 6. Create PR to develop
```

### Scenario 2: Fixing a Bug

```bash
# 1. Create branch
git checkout -b fix/cleanup-script-error

# 2. Make fix
vim cleanup-colima.sh
# Fix the bug

# 3. Test the fix
./cleanup-colima.sh --check

# 4. Commit
git add cleanup-colima.sh
git commit -m "fix: resolve array iteration error in cleanup script

The script was failing when no Docker images were present.
Added check for empty image list before iteration.

Fixes #45"

# 5. Push and PR
git push origin fix/cleanup-script-error
```

### Scenario 3: Updating Documentation

```bash
# 1. Branch for docs
git checkout -b docs/improve-component-guide

# 2. Make changes
vim docs/components.md

# 3. Commit
git add docs/components.md
git commit -m "docs: add examples for component dependencies"

# 4. Push and PR
git push origin docs/improve-component-guide
```

## Troubleshooting

### Git Issues

**Merge conflicts with develop:**
```bash
# Update your branch with latest develop
git checkout develop
git pull upstream develop
git checkout your-branch
git rebase develop
# Resolve conflicts
git add .
git rebase --continue
```

**Accidentally committed to main:**
```bash
# Move commits to new branch
git checkout -b fix/my-fix
git checkout main
git reset --hard upstream/main
git checkout fix/my-fix
```

### PR Issues

**PR has conflicts:**
1. Update your local develop
2. Rebase your branch on develop
3. Force push: `git push origin your-branch --force-with-lease`

**PR checks failing:**
- Review the error messages
- Fix issues locally
- Push fixes to the same branch

### Testing Issues

**Can't connect to container:**
```bash
# Check pod status
kubectl get pods -n ai-devkit

# Check port forwarding
lsof -i :2222
lsof -i :8090

# Restart port forwarding
pkill -f "kubectl.*port-forward"
kubectl port-forward -n ai-devkit service/ai-devkit 2222:22 8090:8090
```

## Best Practices

1. **Keep PRs focused**: One feature/fix per PR
2. **Write clear commit messages**: Future you will thank you
3. **Test thoroughly**: Don't assume it works
4. **Update documentation**: If you change behavior, update docs
5. **Ask questions**: Use issues/discussions if unsure
6. **Be patient**: PRs may take time to review

## Getting Help

- **Questions**: Open an issue with the `question` label
- **Discussions**: Use GitHub Discussions for general topics
- **Real-time help**: Consider joining our community chat (if available)

Remember: Everyone was new once. Don't hesitate to ask for help!
