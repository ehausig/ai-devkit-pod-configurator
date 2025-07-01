# MANDATORY Development Protocol

## STOP! READ THIS FIRST
You MUST follow EVERY step in this document. No exceptions. No shortcuts.

## Communication Style
Be conversational, but ALWAYS follow the protocol below exactly.

## Step-by-Step Development Protocol

### STEP 1: Session Initialization (DO THIS FIRST - NO EXCEPTIONS)
Begin by understanding the task requirements and determining the appropriate project structure.

### STEP 2: Project Setup (REQUIRED FOR ALL NEW PROJECTS)

1. **Determine project type and approach**:
   Choose the appropriate setup based on project needs:
   - FULL: Production-ready with GitHub, CI/CD, full testing
   - PROTOTYPE: Fast experimentation, local git only
   - LIBRARY: Package/module for distribution

2. **Ask clarifying questions first** if requirements are unclear.

3. **Choose project structure**:
   - Single app: `PROJECT_ROOT="~/workspace/PROJECT_NAME"`
   - Monorepo: Define root and app directories appropriately

### FULL SETUP PATH (Production-Ready Projects)

4. **Create GitHub repository**:
   ```bash
   # Create the project directory FIRST
   mkdir -p PROJECT_NAME
   cd PROJECT_NAME
   
   # Initialize git repo locally
   git init
   
   # Create initial files
   echo "# PROJECT_NAME" > README.md
   touch requirements.txt .gitignore
   
   # Initial commit
   git add .
   git commit -m "Initial commit"
   
   # Create GitHub repo and add remote
   gh repo create PROJECT_NAME --public --description "PROJECT_DESCRIPTION"
   
   # Add remote and push if repo creation succeeded
   if gh repo view PROJECT_NAME &>/dev/null; then
       git remote add origin https://github.com/USERNAME/PROJECT_NAME.git
       git branch -M main
       git push -u origin main
   fi
   ```

5. **Initialize Git workflow**:
   ```bash
   # Create develop branch
   git checkout -b develop
   git push -u origin develop 2>/dev/null || echo "Working locally only"
   
   # Enable auto-merge if on GitHub
   gh repo edit --enable-auto-merge 2>/dev/null || true
   ```

### PROTOTYPE PATH (Fast Experimentation)

4. **Quick local setup**:
   ```bash
   mkdir -p PROJECT_NAME
   cd PROJECT_NAME
   git init
   
   # Minimal structure
   mkdir -p src tests
   touch README.md .gitignore
   
   # Quick commit
   git add .
   git commit -m "Initial prototype"
   ```

### COMMON SETUP (All Paths)

6. **Create project structure** based on project template:
   ```bash
   # API Project
   mkdir -p src/{api,models,services} tests/{unit,integration,e2e} docs config
   
   # CLI Tool
   mkdir -p src/{commands,utils} tests/{unit,integration,e2e} docs
   
   # Library/Package
   mkdir -p src tests/{unit,integration} docs examples
   
   ls -la
   ```

7. **Environment configuration**:
   ```bash
   # Create .env.example (never commit real .env)
   cat > .env.example << 'EOF'
   # Application settings
   APP_ENV=development
   DATABASE_URL=postgresql://user:pass@localhost/dbname
   API_KEY=your-api-key-here
   EOF
   
   cp .env.example .env
   echo ".env" >> .gitignore
   ```

8. **Setup pre-commit hooks** (optional but recommended).

### STEP 3: Development Cycle (FOLLOW THIS EXACT ORDER)

#### 3.1 Create Feature Branch (ALWAYS DO THIS FIRST)
```bash
git checkout develop  # Always branch from develop
git pull origin develop  # Ensure up to date
git checkout -b feat/FEATURE_NAME
```

#### 3.2 Create Development Environment
Follow the environment setup instructions for your language/tool:
- Python: conda/venv creation
- Node.js: npm init
- Go: go mod init
- Rust: cargo init
- Ruby: bundle init

#### 3.3 Write Tests FIRST (TDD is MANDATORY)

**Testing Philosophy**
The project MUST include three levels of testing:
1. **Unit Tests** - Test individual functions/methods in isolation
2. **Integration Tests** - Test component interactions, databases, APIs
3. **User Simulation Tests** - Test the actual user experience end-to-end

**Create test structure**:
```bash
mkdir -p tests/unit tests/integration tests/e2e
```

Write tests that describe behavior, not implementation. Each test should have a clear ARRANGE-ACT-ASSERT structure.

#### 3.4 Run Tests (MUST FAIL FIRST - This proves TDD)
Run the test command for your language. The test MUST fail at this point.

#### 3.5 Implement Feature (NOW you can code)
Implement the minimum code necessary to make the tests pass.

#### 3.6 Run Tests Again (MUST PASS NOW)
Run ALL test levels:
1. Unit tests (fastest, run first)
2. Integration tests (slower, run second)
3. User simulation tests (slowest, run last)

ALL test levels must pass before proceeding.

#### 3.7 Fix Until All Tests Pass
If any test fails, analyze the error and fix the code. Common recovery strategies:
- Check error messages and stack traces
- Add debug logging
- Verify test assumptions
- Check for race conditions
- Ensure proper test isolation

#### 3.8 Update Documentation
Ensure comprehensive documentation including:
- README.md with installation and usage instructions
- API documentation if applicable
- Configuration documentation
- Architecture Decision Records for complex projects

#### 3.9 Commit ONLY When All Tests Pass
```bash
# Verify all tests pass
# Stage changes
git add .
git status

# Commit with conventional format
git commit -m "feat(SCOPE): description of feature

- Detail 1
- Detail 2

Closes #ISSUE"
```

#### 3.10 Push and Create Pull Request
```bash
# Push to remote
git push origin feat/FEATURE_NAME

# Create PR if GitHub remote exists
if git remote get-url origin &>/dev/null && gh repo view &>/dev/null; then
    gh pr create \
      --title "feat: FEATURE_NAME" \
      --body "## Changes
- List specific changes

## Testing
- ✅ All unit tests pass
- ✅ Integration tests verified
- ✅ User simulation tests pass

## Checklist
- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] No security vulnerabilities
- [ ] Follows code style guidelines" \
      --base develop
      
    # Enable auto-merge if available
    gh pr merge --auto --squash --delete-branch 2>/dev/null || true
fi
```

### STEP 4: Session Completion
Review the work completed and ensure all tests pass, documentation is updated, and code is properly committed.

## TUI Testing with Microsoft TUI Test

This environment includes Microsoft TUI Test pre-installed. Use it for testing ANY terminal application:

```bash
# Create config file
tui-test-init  # Creates tui-test.config.ts

# Create example test
tui-test-example  # Creates example.test.ts

# Run tests
tui-test
npx @microsoft/tui-test --trace
```

## Project Templates

### CLI Tool Template
```bash
mkdir -p src/{commands,utils,config} tests/{unit,integration,e2e} docs examples
touch src/cli.py  # or main.go, cli.js, etc.
```

### Web API Template  
```bash
mkdir -p src/{api,models,services,middleware} tests/{unit,integration,e2e} docs migrations
touch src/app.py  # or server.js, main.go, etc.
touch requirements.txt Dockerfile docker-compose.yml
```

### TUI Application Template
```bash
mkdir -p src/{ui,components,state} tests/{unit,integration,e2e} docs assets
touch src/app.py  # Main TUI entry point
touch tui-test.config.ts  # For Microsoft TUI Test
```

### Library/Package Template
```bash
mkdir -p src tests/{unit,integration} docs examples benchmarks
touch setup.py pyproject.toml  # or package.json, Cargo.toml, etc.
touch LICENSE CONTRIBUTING.md
```

## Error Recovery Strategies

### GitHub repo creation fails
Continue with local development and manually create repo later.

### Merge conflicts
For automated resolution:
- Accept theirs for generated files: `git checkout --theirs package-lock.json`
- Accept ours for config files: `git checkout --ours .env.example`
- Manual resolution required for source code

### Test failures after multiple attempts
After 3 attempts, consider:
- Marking test as flaky and skip temporarily
- Simplifying test case
- Adding debugging output
- Creating issue for investigation

### Dependency conflicts
Try resolution strategies based on language:
- Python: `pip install --force-reinstall`
- Node: `npm install --force`
- Go: `go mod tidy`

## Security Considerations

### Local Security Scanning
Run security scans locally in the container using language-appropriate tools.

### Secret Management
NEVER commit secrets or sensitive data. Use environment variables or secret management tools.

Add to .gitignore:
```
.env
.env.*
*.key
*.pem
secrets/
credentials/
```

## Critical Rules

### Testing Requirements
1. **Three-Tier Testing Strategy** (Unit, Integration, User Simulation)
2. **Test Organization** in separate directories
3. **Coverage Requirements**: Minimum 80% for unit tests

### DO NOT:
- Create git repositories inside other git repositories
- Push code without ALL tests passing
- Skip error handling and recovery steps
- Commit secrets or sensitive data

### ALWAYS:
- Use proper environment activation
- Create comprehensive test suites
- Follow language-specific conventions
- Handle errors gracefully
- Document architectural decisions

## VERIFICATION CHECKLIST
Before considering ANY task complete:
- [ ] Project is in correct directory structure
- [ ] No nested git repositories
- [ ] All test files have actual test implementations
- [ ] Integration tests verify real behavior
- [ ] All tests are passing
- [ ] Documentation is comprehensive
- [ ] PR is created and auto-merge enabled

---
*Note: All actions are automatically logged to ~/workspace/JOURNAL.md by the hooks system.*

## Base Development Tools

This environment always includes these pre-installed tools:

### Core Tools
- Git @~/.claude/nodejs-base.md
- GitHub CLI (gh)
- SSH Server
- Node.js 20.18.0 @~/.claude/nodejs-base.md
- Microsoft TUI Test (see TUI Testing section above)
- sed (GNU sed) 4.8
- Ubuntu
