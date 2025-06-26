# Maintainer Guide

This guide covers the responsibilities and procedures for maintaining the AI DevKit Pod Configurator project.

## Table of Contents

1. [Repository Setup](#repository-setup)
2. [Branch Protection](#branch-protection)
3. [Pull Request Management](#pull-request-management)
4. [Release Process](#release-process)
5. [Version Management](#version-management)
6. [Hotfix Procedures](#hotfix-procedures)

## Repository Setup

### GitHub Repository Settings

Configure these settings in your GitHub repository:

1. **General Settings**
   ```
   Settings → General
   - Default branch: main
   - Features:
     ✓ Issues
     ✓ Preserve this repository
     ✓ Discussions (optional)
   - Pull Requests:
     ✓ Allow squash merging
     ✓ Allow rebase merging
     ✗ Allow merge commits (disable for clean history)
     ✓ Automatically delete head branches
   ```

2. **Branch Protection Rules**
   
   See [Branch Protection](#branch-protection) section below.

3. **Actions Settings**
   ```
   Settings → Actions → General
   - Actions permissions: Allow all actions
   - Workflow permissions: Read and write permissions
   ```

## Branch Protection

### Protected Branches Configuration

1. **`main` branch protection:**
   ```
   Settings → Branches → Add rule
   - Branch name pattern: main
   - ✓ Require pull request reviews before merging
     - Required approving reviews: 1
     - ✓ Dismiss stale pull request approvals
   - ✓ Require status checks to pass
     - ✓ Require branches to be up to date
   - ✓ Require conversation resolution
   - ✓ Require linear history
   - ✓ Include administrators
   - ✗ Allow force pushes (never!)
   ```

2. **`develop` branch protection:**
   ```
   Settings → Branches → Add rule
   - Branch name pattern: develop
   - ✓ Require pull request reviews before merging
     - Required approving reviews: 1
   - ✓ Require conversation resolution
   - ✓ Include administrators
   - ✗ Allow force pushes
   ```

## Pull Request Management

### Review Process

1. **Initial Review Checklist**
   ```bash
   # Check out the PR locally
   git fetch origin pull/PR_NUMBER/head:pr-PR_NUMBER
   git checkout pr-PR_NUMBER
   
   # Run basic checks
   shellcheck scripts/*.sh
   
   # Test the build
   ./build-and-deploy.sh
   ```

2. **Code Review Guidelines**
   - Check for conventional commit messages
   - Verify documentation updates
   - Ensure no breaking changes without version bump
   - Test functionality locally
   - Review for security issues

3. **Feedback Template**
   ```markdown
   ## Review Summary
   
   **Status**: Approved ✅ / Changes Requested 🔄 / Comment 💭
   
   ### Strengths
   - Clear implementation of X
   - Good test coverage
   
   ### Suggestions
   - Consider extracting Y to a function
   - Add error handling for Z
   
   ### Required Changes (if any)
   - [ ] Fix shellcheck warnings in line X
   - [ ] Update documentation for new feature
   ```

### Merging Pull Requests

1. **For Feature PRs (to develop)**
   ```bash
   # Ensure PR is up to date
   # GitHub UI: Update branch button
   
   # Or via CLI:
   git checkout develop
   git pull origin develop
   git checkout pr-PR_NUMBER
   git rebase develop
   git push --force-with-lease
   
   # Merge via GitHub UI using Squash and Merge
   # Edit the commit message to follow conventional format
   ```

2. **For Release PRs (develop to main)**
   - Always use "Create a merge commit"
   - Never squash release PRs
   - Ensure version is bumped
   - Verify CHANGELOG is updated

## Release Process

### Creating a Release

1. **Prepare the Release**
   ```bash
   # Ensure you're on develop and up to date
   git checkout develop
   git pull origin develop
   
   # Run the release script
   ./scripts/create-release.sh
   # Choose: patch/minor/major
   # Script will:
   # - Bump version
   # - Generate changelog
   # - Create PR
   ```

2. **Review the Release PR**
   - Verify version bump is correct
   - Review CHANGELOG entries
   - Check all tests pass
   - Ensure no unwanted changes

3. **Merge the Release**
   ```bash
   # Merge via GitHub UI
   # Use "Create a merge commit" (not squash!)
   ```

4. **Post-Merge Tasks**
   ```bash
   # The create-release script generates a post-merge script
   # Run it after PR is merged:
   ./release-vX.Y.Z-post-merge.sh
   
   # This script will:
   # - Create and push git tag
   # - Create GitHub release
   # - Merge main back to develop
   # - Self-delete
   ```

### Manual Release Process

If scripts fail, here's the manual process:

```bash
# 1. On develop branch
git checkout develop
git pull origin develop

# 2. Bump version
echo "X.Y.Z" > VERSION

# 3. Generate changelog
./scripts/generate-changelog.sh

# 4. Commit
git add VERSION CHANGELOG.md
git commit -m "chore: prepare release vX.Y.Z"

# 5. Push and create PR
git push origin develop
gh pr create --base main --head develop \
  --title "chore: release vX.Y.Z" \
  --body "Release vX.Y.Z"

# 6. After merge, on main:
git checkout main
git pull origin main

# 7. Tag the release
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z

# 8. Create GitHub release
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes-file CHANGELOG.md

# 9. Merge back to develop
git checkout develop
git merge main
git push origin develop
```

## Version Management

### Semantic Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (X.0.0): Breaking changes
  - Removing components
  - Changing component APIs
  - Incompatible configuration changes
  
- **MINOR** (0.X.0): New features, backwards compatible
  - Adding new components
  - Adding new configuration options
  - New themes or UI features
  
- **PATCH** (0.0.X): Bug fixes
  - Fixing component installations
  - UI bug fixes
  - Documentation updates

### Version Decision Tree

```
Is it a breaking change?
├─ Yes → MAJOR version
└─ No
   ├─ Does it add functionality?
   │  ├─ Yes → MINOR version
   │  └─ No → PATCH version
```

### Pre-release Versions

For testing releases:

```bash
# For release candidates
echo "1.0.0-rc.1" > VERSION

# For beta releases
echo "1.0.0-beta.1" > VERSION
```

## Hotfix Procedures

For critical bugs in production:

1. **Create Hotfix Branch**
   ```bash
   # From main, not develop!
   git checkout main
   git pull origin main
   git checkout -b hotfix/critical-bug-description
   ```

2. **Fix and Test**
   ```bash
   # Make minimal changes
   # Test thoroughly
   git add .
   git commit -m "fix: critical bug description"
   ```

3. **Create PR to Main**
   ```bash
   git push origin hotfix/critical-bug-description
   gh pr create --base main \
     --title "fix: critical bug description" \
     --body "Fixes #issue"
   ```

4. **After Merge**
   ```bash
   # Tag as patch release
   git checkout main
   git pull origin main
   
   # Bump patch version
   ./scripts/bump-version.sh patch
   git add VERSION
   git commit -m "chore: bump version for hotfix"
   git push origin main
   
   # Tag and release
   git tag -a vX.Y.Z -m "Hotfix release vX.Y.Z"
   git push origin vX.Y.Z
   
   # Merge back to develop
   git checkout develop
   git merge main
   git push origin develop
   ```

## Maintenance Tasks

### Weekly Tasks

1. **Review Open PRs**
   - Provide feedback or merge
   - Close stale PRs with explanation

2. **Triage Issues**
   - Label new issues
   - Respond to questions
   - Close resolved issues

### Monthly Tasks

1. **Dependency Review**
   - Check for outdated base images
   - Review component versions
   - Update if needed (minor version bump)

2. **Documentation Review**
   - Check for outdated information
   - Update examples
   - Improve clarity based on issues

### Release Checklist Template

```markdown
## Release vX.Y.Z Checklist

### Pre-release
- [ ] All PRs for this release merged to develop
- [ ] CI/CD passing on develop
- [ ] Manual testing completed
- [ ] Documentation updated
- [ ] CHANGELOG reflects all changes

### Release
- [ ] Version bumped
- [ ] CHANGELOG generated
- [ ] Release PR created
- [ ] Release PR reviewed
- [ ] Release PR merged

### Post-release
- [ ] Git tag created and pushed
- [ ] GitHub release created
- [ ] Main merged back to develop
- [ ] Announcement made (if major/minor)
```

## Communication

### Release Announcements

For minor and major releases:

1. **GitHub Release Notes**
   - Summary of major changes
   - Migration instructions (if any)
   - Thanks to contributors

2. **Issue/PR Comments**
   - Notify relevant issues that they're fixed
   - Thank contributors

### Responding to Issues

- Acknowledge within 48 hours
- Ask for clarification if needed
- Label appropriately
- Link to related issues/PRs

## Security

### Security Issues

1. **Never** commit secrets
2. Review PRs for exposed credentials
3. Use GitHub's security alerts
4. Respond to security issues within 24 hours

### Vulnerable Dependencies

When security alerts appear:

1. Assess the impact
2. Create a hotfix if critical
3. Update dependency
4. Release as patch version

## Useful Commands Reference

```bash
# View release history
git tag -l --sort=-version:refname

# Compare releases
git diff v1.0.0..v1.1.0

# Cherry-pick a commit to another branch
git cherry-pick COMMIT_SHA

# View changelog for specific version
git show v1.0.0:CHANGELOG.md

# List contributors
git shortlog -sn --all
```
