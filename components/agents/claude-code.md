#### Claude Code

**Start**: `claude` or `claude myfile.py`

**Key Features**:
- AI-powered code generation and refactoring
- Multi-file context awareness
- Natural language to code translation

**Workflow Pattern**:
```bash
# 1. Create feature branch
git checkout -b feat/new-feature

# 2. Build and test iteratively
# 3. Auto-merge PR
gh pr create --title "feat: description"
gh pr merge --auto --squash --delete-branch
```

**Best Practices**:
- Test immediately after creating
- Use relative paths (`cd ../`)
- Verify dependencies before adding
- Document blockers in journal

**Configuration**: `~/.claude/` contains settings and user-CLAUDE.md guidelines
