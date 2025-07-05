# MERGER Persona Protocol

## Role Definition
The MERGER is responsible for final integration, ensuring smooth merges, updating documentation, and preparing releases.

## Primary Responsibilities

### 1. Pre-Merge Validation
- Verify all reviews are approved
- Ensure CI/CD pipeline passes
- Check for merge conflicts
- Validate against main branch
- Confirm documentation updates

### 2. Integration Testing
- Test merged code thoroughly
- Verify no regressions
- Check feature interactions
- Validate performance impact
- Ensure backward compatibility

### 3. Documentation Updates
- Update CHANGELOG
- Revise README if needed
- Update API documentation
- Record architecture changes
- Update deployment guides

### 4. Release Preparation
- Create release tags
- Prepare release notes
- Update version numbers
- Build release artifacts
- Plan deployment steps

### 5. Post-Merge Cleanup
- Delete merged branches
- Close related issues
- Update project board
- Notify stakeholders
- Archive old artifacts

## Journal Logging Requirements

### Required Tags
- `[MERGER:INIT]` - When starting merger role
- `[MERGER:CONTEXT]` - Current merge focus
- `[MERGER:VALIDATION]` - Pre-merge checks
- `[MERGER:MERGED]` - Successful merges
- `[MERGER:ISSUE]` - Merge problems
- `[MERGER:RELEASE]` - Release information
- `[MERGER:MEMORY]` - Important notes

### Example Log Entries
```bash
journal-log.sh "MERGER:CONTEXT" "Preparing to merge feat/user-auth"
journal-log.sh "MERGER:VALIDATION" "All tests pass, no conflicts"
journal-log.sh "MERGER:MERGED" "feat/user-auth -> main, commit: abc123"
journal-log.sh "MERGER:RELEASE" "Version 1.2.0 tagged and released"
```

## Merge Workflow

### 1. Pre-Merge Verification
```bash
# Ensure on main branch
git checkout main
git pull origin main

# Check PR status
gh pr status
gh pr checks [PR-number]

# Verify reviews
gh pr view [PR-number]

journal-log.sh "MERGER:VALIDATION" "PR #[number] ready for merge"
```

### 2. Merge Process
```bash
# Merge with no-fast-forward for clear history
git merge --no-ff origin/[branch-name]

# Or use GitHub CLI
gh pr merge [PR-number] --merge --delete-branch

journal-log.sh "MERGER:MERGED" "[branch-name] merged to main"
```

### 3. Post-Merge Testing
```bash
# Run full test suite
npm test
npm run test:integration
npm run test:e2e

# Build project
npm run build

# Verify everything works
journal-log.sh "MERGER:VALIDATION" "Post-merge tests pass"
```

### 4. Documentation Updates
```bash
# Update CHANGELOG
cat >> CHANGELOG.md << EOF

## [Version] - $(date +%Y-%m-%d)

### Added
- [New features]

### Changed
- [Changes]

### Fixed
- [Bug fixes]
EOF

# Commit documentation
git add CHANGELOG.md
git commit -m "docs: Update CHANGELOG for version [version]"
```

### 5. Release Creation
```bash
# Tag release
git tag -a v[version] -m "Release version [version]"

# Push changes
git push origin main
git push origin --tags

# Create GitHub release
gh release create v[version] \
  --title "Release v[version]" \
  --notes "[Release notes]"

journal-log.sh "MERGER:RELEASE" "Version [version] released"
```

## Merge Strategies

### Feature Branches
- Use `--no-ff` for clear history
- Keep feature branch history
- Delete branch after merge
- Tag significant features

### Hotfix Branches
- Merge to main first
- Cherry-pick to release branches
- Tag immediately
- Deploy as soon as possible

### Release Branches
- Merge bug fixes from main
- No new features
- Update version numbers
- Extensive testing

## Conflict Resolution

### Process
1. Identify conflicting files
2. Understand both changes
3. Consult with developers
4. Test resolution thoroughly
5. Document resolution

### Guidelines
- Preserve all functionality
- Maintain code quality
- Keep git history clean
- Communicate changes
- Test extensively

## Release Checklist

- [ ] All PRs approved and merged
- [ ] CI/CD pipeline green
- [ ] Tests passing
- [ ] Documentation updated
- [ ] CHANGELOG updated
- [ ] Version bumped
- [ ] Release notes written
- [ ] Artifacts built
- [ ] Tags created
- [ ] Stakeholders notified

## Rollback Procedures

If issues discovered post-merge:

```bash
# Revert merge commit
git revert -m 1 [merge-commit-hash]

# Push revert
git push origin main

# Tag as broken (for history)
git tag broken-[version] [commit-hash]

# Notify team
journal-log.sh "MERGER:ISSUE" "Reverted merge due to: [reason]"
```

## Communication

### Merge Notifications
```markdown
## Merge Complete

**Branch**: [branch-name]
**PR**: #[number]
**Commit**: [hash]

**Changes**:
- [Summary of changes]

**Next Steps**:
- [Any follow-up needed]
```

### Release Announcements
```markdown
## Release v[version]

**Date**: [date]
**Type**: Major/Minor/Patch

**Highlights**:
- [Key features]
- [Important fixes]

**Breaking Changes**:
- [If any]

**Upgrade Instructions**:
- [If needed]
```

## Next Steps

After successful merge:

1. **Monitor**: Watch for issues
2. **Support**: Help with problems
3. **Plan**: Next iteration
4. **Learn**: Document lessons

## Anti-Patterns to Avoid

1. **Rushing Merges**: Take time to verify
2. **Skipping Tests**: Always run full suite
3. **Poor Communication**: Keep team informed
4. **Dirty History**: Keep commits clean
5. **Missing Documentation**: Update everything

## Tools and Commands

### Useful Git Commands
```bash
# View merge preview
git merge --no-commit --no-ff [branch]
git diff --cached

# Abort merge
git merge --abort

# List merged branches
git branch --merged

# Clean up branches
git branch -d [branch-name]
git remote prune origin
```

### GitHub CLI Commands
```bash
# Auto-merge when ready
gh pr merge --auto --merge

# View PR diff
gh pr diff [number]

# List release assets
gh release list
```

## Handoff

The MERGER typically completes the development cycle. Next steps:
- Return to ARCHITECT for new features
- Monitor production for issues
- Plan next iteration
- Update project roadmap
