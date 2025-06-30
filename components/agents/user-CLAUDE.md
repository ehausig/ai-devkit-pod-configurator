# MANDATORY Development Protocol

## STOP! READ THIS FIRST
You MUST follow EVERY step in this document. No exceptions. No shortcuts.

## Communication Style
Be conversational, but ALWAYS follow the protocol below exactly.

## Path Navigation Rules

### CRITICAL: Working with Paths
- **NEVER use `~/workspace` in cd commands** - Claude Code interprets this incorrectly
- **Always use relative paths from current directory**
- **Use these patterns:**
  ```bash
  # WRONG:
  cd ~/workspace/project-name  # This will fail!
  
  # CORRECT:
  cd project-name              # From workspace directory
  cd ../project-name           # From sibling directory
  cd /home/devuser/workspace/project-name  # Absolute path if needed
  ```

### Navigation Examples:
```bash
# Creating and entering a project directory
mkdir -p project-name
cd project-name

# Moving between directories
pwd  # Always check where you are first
cd ../another-project  # Move to sibling
cd /home/devuser/workspace  # Return to workspace root
```

## Step-by-Step Development Protocol

### STEP 1: Session Initialization (DO THIS FIRST - NO EXCEPTIONS)
```bash
# You MUST execute these commands at the start of EVERY session:
echo "$(date -Iseconds) [INFO] Session started - $TASK_DESCRIPTION" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] Working directory: $(pwd)" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] User request: $USER_REQUEST" >> ~/workspace/JOURNAL.md
```

### STEP 2: Project Setup (REQUIRED FOR ALL NEW PROJECTS)

1. **Determine project type and approach**:
   ```bash
   # Choose appropriate setup based on project needs:
   # - FULL: Production-ready with GitHub, CI/CD, full testing
   # - PROTOTYPE: Fast experimentation, local git only
   # - LIBRARY: Package/module for distribution
   
   echo "$(date -Iseconds) [DECISION] Project type: TYPE chosen because REASON" >> ~/workspace/JOURNAL.md
   ```

2. **Ask clarifying questions first**:
   ```bash
   echo "$(date -Iseconds) [DECISION] Clarification needed on: $QUESTION" >> ~/workspace/JOURNAL.md
   ```

3. **Project structure decision**:
   ```bash
   # For single app:
   PROJECT_ROOT="~/workspace/PROJECT_NAME"
   
   # For monorepo:
   PROJECT_ROOT="~/workspace/PROJECT_NAME"
   APP_DIR="$PROJECT_ROOT/APP_NAME"
   
   echo "$(date -Iseconds) [DECISION] Project structure: TYPE chosen because REASON" >> ~/workspace/JOURNAL.md
   ```

### FULL SETUP PATH (Production-Ready Projects)

4. **Create GitHub repository**:
   ```bash
   # Create the project directory FIRST
   mkdir -p PROJECT_NAME
   cd PROJECT_NAME
   
   # Initialize git repo locally
   git init
   echo "$(date -Iseconds) [INFO] Git repository initialized in $(pwd)" >> ../JOURNAL.md
   
   # Create initial files
   echo "# PROJECT_NAME" > README.md
   touch requirements.txt .gitignore
   
   # Initial commit
   git add .
   git commit -m "Initial commit"
   
   # Create GitHub repo and add remote
   gh repo create PROJECT_NAME --public --description "PROJECT_DESCRIPTION" || {
       echo "$(date -Iseconds) [ERROR] Failed to create GitHub repo" >> ../JOURNAL.md
       echo "$(date -Iseconds) [RECOVERY] Continuing with local development" >> ../JOURNAL.md
   }
   
   # Add remote and push if repo creation succeeded
   if gh repo view PROJECT_NAME &>/dev/null; then
       git remote add origin https://github.com/USERNAME/PROJECT_NAME.git || true
       git branch -M main
       git push -u origin main
       echo "$(date -Iseconds) [MILESTONE] GitHub repo created and pushed: PROJECT_NAME" >> ../JOURNAL.md
   fi
   ```

5. **Initialize Git workflow**:
   ```bash
   # Create develop branch
   git checkout -b develop
   git push -u origin develop 2>/dev/null || echo "$(date -Iseconds) [INFO] Working locally only" >> ~/workspace/JOURNAL.md
   
   # Enable auto-merge if on GitHub
   gh repo edit --enable-auto-merge 2>/dev/null || true
   echo "$(date -Iseconds) [INFO] Git workflow initialized" >> ~/workspace/JOURNAL.md
   ```

### PROTOTYPE PATH (Fast Experimentation)

4. **Quick local setup**:
   ```bash
   echo "$(date -Iseconds) [INFO] Fast-track prototype mode - minimal setup" >> ~/workspace/JOURNAL.md
   
   mkdir -p PROJECT_NAME
   cd PROJECT_NAME
   git init
   
   # Minimal structure
   mkdir -p src tests
   touch README.md .gitignore
   
   # Quick commit
   git add .
   git commit -m "Initial prototype"
   
   echo "$(date -Iseconds) [INFO] Prototype ready for experimentation" >> ~/workspace/JOURNAL.md
   ```

### COMMON SETUP (All Paths)

6. **Create project structure**:
   ```bash
   # Based on project template (check imported docs for language-specific templates)
   # Common structures:
   
   # API Project
   mkdir -p src/{api,models,services} tests/{unit,integration,e2e} docs config
   
   # CLI Tool
   mkdir -p src/{commands,utils} tests/{unit,integration,e2e} docs
   
   # Library/Package
   mkdir -p src tests/{unit,integration} docs examples
   
   echo "$(date -Iseconds) [INFO] Project structure created" >> ~/workspace/JOURNAL.md
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
   
   echo "$(date -Iseconds) [INFO] Environment configuration created" >> ~/workspace/JOURNAL.md
   ```

8. **Setup pre-commit hooks** (optional but recommended):
   ```bash
   # Install pre-commit hooks locally for code quality
   # This runs checks before each commit in the container
   
   # Python: pip install pre-commit
   # Node: npm install --save-dev husky
   # Go: pre-commit install
   # See language-specific documentation for setup
   
   echo "$(date -Iseconds) [INFO] Pre-commit hooks configured for local development" >> ~/workspace/JOURNAL.md
   ```

### STEP 3: Development Cycle (FOLLOW THIS EXACT ORDER)

#### 3.1 Create Feature Branch (ALWAYS DO THIS FIRST)
```bash
git checkout develop  # Always branch from develop
git pull origin develop  # Ensure up to date
git checkout -b feat/FEATURE_NAME
echo "$(date -Iseconds) [INFO] Created feature branch: feat/FEATURE_NAME" >> ~/workspace/JOURNAL.md
```

#### 3.2 Create Development Environment
```bash
# Check language-specific environment setup in the Environment Tools section below
# Log environment creation
echo "$(date -Iseconds) [INFO] Creating development environment for LANGUAGE" >> ~/workspace/JOURNAL.md

# Follow the environment setup instructions for your language/tool
# Examples:
# - Python: conda/venv creation
# - Node.js: npm init
# - Go: go mod init
# - Rust: cargo init
# - Ruby: bundle init

echo "$(date -Iseconds) [INFO] Development environment created" >> ~/workspace/JOURNAL.md

# Install dependencies according to language conventions
echo "$(date -Iseconds) [INFO] Installing dependencies" >> ~/workspace/JOURNAL.md
# Use language-specific dependency manager (pip, npm, cargo, bundle, etc.)
echo "$(date -Iseconds) [INFO] Dependencies installed" >> ~/workspace/JOURNAL.md
```

#### 3.3 Write Tests FIRST (TDD is MANDATORY)

**Testing Philosophy**
The project MUST include three levels of testing:
1. **Unit Tests** - Test individual functions/methods in isolation
2. **Integration Tests** - Test component interactions, databases, APIs
3. **User Simulation Tests** - Test the actual user experience end-to-end

**Create test structure**:
```bash
# Standard test organization
mkdir -p tests/unit tests/integration tests/e2e
echo "$(date -Iseconds) [INFO] Creating three-tier test structure" >> ~/workspace/JOURNAL.md
```

**Unit Tests** (Foundation):
```bash
# Unit tests verify individual components work correctly
# - Fast execution (milliseconds)
# - No external dependencies (mocked)
# - Test pure logic and calculations
# - Minimum 80% code coverage target

echo "$(date -Iseconds) [INFO] Creating unit tests for FEATURE" >> ~/workspace/JOURNAL.md
# Create focused unit tests that test ONE thing per test
# Name tests descriptively: test_calculate_tax_with_zero_income()
```

**Integration Tests** (Connectivity):
```bash
# Integration tests verify components work together
# - Test database operations
# - Test API endpoints
# - Test file I/O operations
# - Test external service integrations

echo "$(date -Iseconds) [INFO] Creating integration tests for FEATURE" >> ~/workspace/JOURNAL.md
# These may use test databases, mock servers, or containers
```

**User Simulation Tests** (Reality):
```bash
# User simulation tests verify the complete user experience
# - For TUI/CLI: Use Microsoft TUI Test (pre-installed)
# - For Web UI: Use appropriate browser automation
# - Test complete user workflows
# - Verify accessibility and usability

echo "$(date -Iseconds) [INFO] Creating user simulation tests for FEATURE" >> ~/workspace/JOURNAL.md

# TUI Test example setup:
tui-test-init  # Creates tui-test.config.ts
tui-test-example  # Creates example test template
```

**Test Implementation Guidelines**:
- Write tests that describe behavior, not implementation
- Each test should have a clear ARRANGE-ACT-ASSERT structure
- Use descriptive test names that explain what is being tested
- Tests must be deterministic (no random failures)
- Integration tests should clean up after themselves
- User simulation tests should test happy paths and error scenarios

**IMPORTANT**: Check the imported language-specific documentation below for detailed examples of each test type, including:
- Language-specific testing frameworks and tools
- Code examples for each type of test
- Best practices for test organization
- Performance testing considerations
- Property-based testing where applicable

#### 3.4 Run Tests (MUST FAIL FIRST - This proves TDD)
```bash
# Run unit tests - expect failure since we haven't implemented yet
# Use language-specific test command from imported documentation
echo "$(date -Iseconds) [INFO] Running initial tests - expecting failure (TDD)" >> ~/workspace/JOURNAL.md

# Run the test command for your language
# The test MUST fail at this point
TEST_RESULT=$?

if [ $TEST_RESULT -eq 0 ]; then
    echo "$(date -Iseconds) [ERROR] Tests passed without implementation - not following TDD" >> ~/workspace/JOURNAL.md
    exit 1
fi

echo "$(date -Iseconds) [INFO] Tests failed as expected (TDD) - proceeding with implementation" >> ~/workspace/JOURNAL.md
```

#### 3.5 Implement Feature (NOW you can code)
```bash
echo "$(date -Iseconds) [DECISION] Implementation approach: DESCRIPTION" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] Starting implementation of FEATURE" >> ~/workspace/JOURNAL.md

# Log each file created
# When creating files, log it:
echo "$(date -Iseconds) [INFO] Created file: FILENAME with PURPOSE" >> ~/workspace/JOURNAL.md

# After implementation
echo "$(date -Iseconds) [INFO] Implementation completed - FILES created/modified" >> ~/workspace/JOURNAL.md
```

#### 3.6 Run Tests Again (MUST PASS NOW)
```bash
# Run ALL test levels locally in the container
echo "$(date -Iseconds) [INFO] Running complete test suite in container" >> ../JOURNAL.md

# 1. Unit tests (fastest, run first)
echo "$(date -Iseconds) [INFO] Running unit tests" >> ../JOURNAL.md
# [Language-specific unit test command from imported docs]
UNIT_RESULT=$?

# 2. Integration tests (slower, run second)
echo "$(date -Iseconds) [INFO] Running integration tests" >> ../JOURNAL.md
# [Language-specific integration test command from imported docs]
INTEGRATION_RESULT=$?

# 3. User simulation tests (slowest, run last)
echo "$(date -Iseconds) [INFO] Running user simulation tests" >> ../JOURNAL.md
# [Language-specific e2e test command from imported docs]
# For TUI apps: npx @microsoft/tui-test
E2E_RESULT=$?

# Log results
echo "$(date -Iseconds) [INFO] Test results - Unit: $UNIT_RESULT, Integration: $INTEGRATION_RESULT, E2E: $E2E_RESULT" >> ../JOURNAL.md

if [ $UNIT_RESULT -ne 0 ] || [ $INTEGRATION_RESULT -ne 0 ] || [ $E2E_RESULT -ne 0 ]; then
    echo "$(date -Iseconds) [ERROR] Tests failed - stopping" >> ../JOURNAL.md
    # STOP and fix!
fi

# ALL test levels must pass before proceeding
echo "$(date -Iseconds) [SUCCESS] All tests passing locally" >> ../JOURNAL.md
```

#### 3.7 Fix Until All Tests Pass
```bash
# If any test fails:
echo "$(date -Iseconds) [ERROR] Test failed: TEST_NAME - REASON" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [DECISION] Fix approach: APPROACH" >> ~/workspace/JOURNAL.md

# Common recovery strategies:
# 1. Check error messages and stack traces
# 2. Add debug logging
# 3. Verify test assumptions
# 4. Check for race conditions (especially in integration tests)
# 5. Ensure proper test isolation

# Fix the code...
echo "$(date -Iseconds) [RESOLUTION] Fixed by: SOLUTION" >> ~/workspace/JOURNAL.md

# Re-run specific failing test first
# [Language-specific command to run single test]

# If still failing after 3 attempts:
if [ $ATTEMPTS -gt 3 ]; then
    echo "$(date -Iseconds) [ESCALATION] Unable to fix test after 3 attempts" >> ~/workspace/JOURNAL.md
    echo "$(date -Iseconds) [DECISION] Alternative approach: DESCRIPTION" >> ~/workspace/JOURNAL.md
    # Consider: simplifying test, breaking into smaller tests, or marking as known issue
fi

# Re-run full test suite once individual test passes
```

#### 3.8 Update Documentation
```bash
# Ensure comprehensive documentation
echo "$(date -Iseconds) [INFO] Updating documentation" >> ~/workspace/JOURNAL.md

# Create README.md with the following template:
```

**README.md Template:**
```markdown
# PROJECT_NAME

Brief description of what this project does.

## Features

- Feature 1
- Feature 2

## Installation

\`\`\`bash
# Installation commands here
\`\`\`

## Usage

\`\`\`bash
# Basic usage examples
\`\`\`

## Development

### Prerequisites
- List requirements

### Setup
\`\`\`bash
# Development setup commands
\`\`\`

### Testing
\`\`\`bash
# Run unit tests
make test-unit

# Run all tests
make test
\`\`\`

## API Documentation

[If applicable, link to API docs or include basic endpoints]

## Configuration

See `.env.example` for required environment variables.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feat/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feat/amazing-feature`)
5. Open a Pull Request

## License

[License type]
```

```bash
# Also create CHANGELOG.md
echo "# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Initial version
" > CHANGELOG.md

# Architecture Decision Records (for complex projects)
if [ "$PROJECT_TYPE" = "FULL" ]; then
    mkdir -p docs/adr
    echo "$(date -Iseconds) [INFO] Created ADR directory for architecture decisions" >> ~/workspace/JOURNAL.md
fi

echo "$(date -Iseconds) [INFO] Documentation updated - README.md and CHANGELOG.md complete" >> ~/workspace/JOURNAL.md
```

#### 3.9 Commit ONLY When All Tests Pass
```bash
# Verify all tests pass using language-specific test runner
echo "$(date -Iseconds) [INFO] Verifying all tests pass before commit" >> ~/workspace/JOURNAL.md

# Stage changes
git add .
git status
echo "$(date -Iseconds) [INFO] Staged changes for commit" >> ~/workspace/JOURNAL.md

# Commit with conventional format
git commit -m "feat(SCOPE): description of feature

- Detail 1
- Detail 2

Closes #ISSUE"
echo "$(date -Iseconds) [MILESTONE] Committed: $(git log -1 --pretty=format:'%s')" >> ~/workspace/JOURNAL.md
```

#### 3.10 Push and Create Pull Request
```bash
# Push to remote
git push origin feat/FEATURE_NAME 2>/dev/null || {
    echo "$(date -Iseconds) [WARNING] No remote repository, skipping push" >> ~/workspace/JOURNAL.md
    echo "$(date -Iseconds) [INFO] Code remains in local feature branch" >> ~/workspace/JOURNAL.md
    exit 0
}

echo "$(date -Iseconds) [INFO] Pushed to remote" >> ~/workspace/JOURNAL.md

# Create PR (if GitHub remote exists)
if git remote get-url origin &>/dev/null && gh repo view &>/dev/null; then
    PR_URL=$(gh pr create \
      --title "feat: FEATURE_NAME" \
      --body "## Changes
- List specific changes

## Testing
- ✅ All unit tests pass
- ✅ Integration tests verified
- ✅ User simulation tests pass

## Screenshots
[Add if applicable]

## Checklist
- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] No security vulnerabilities
- [ ] Follows code style guidelines" \
      --base develop) || {
        echo "$(date -Iseconds) [ERROR] Failed to create PR" >> ~/workspace/JOURNAL.md
        echo "$(date -Iseconds) [INFO] Changes remain in feature branch" >> ~/workspace/JOURNAL.md
      }
      
    if [ -n "$PR_URL" ]; then
        echo "$(date -Iseconds) [MILESTONE] Pull request created: $PR_URL" >> ~/workspace/JOURNAL.md
        
        # Enable auto-merge if available
        gh pr merge --auto --squash --delete-branch 2>/dev/null && \
            echo "$(date -Iseconds) [INFO] Auto-merge enabled for PR" >> ~/workspace/JOURNAL.md
    fi
else
    echo "$(date -Iseconds) [INFO] No GitHub remote, merging locally" >> ~/workspace/JOURNAL.md
    git checkout develop
    git merge --no-ff feat/FEATURE_NAME -m "feat: FEATURE_NAME"
    echo "$(date -Iseconds) [MILESTONE] Feature merged to develop branch locally" >> ~/workspace/JOURNAL.md
fi
```

### STEP 4: Session Completion
```bash
# Final summary
echo "$(date -Iseconds) [MILESTONE] Session completed successfully" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] Final test summary:" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] - Unit tests: PASSED with X tests" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] - Integration tests: PASSED with Y tests" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] - User simulation tests: PASSED with Z tests" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] - All tests run locally in container" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] - Repository: $(git remote get-url origin 2>/dev/null || echo 'Local only')" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] - Current branch: $(git branch --show-current)" >> ~/workspace/JOURNAL.md
if [ -n "$PR_URL" ]; then
    echo "$(date -Iseconds) [INFO] - PR: $PR_URL" >> ~/workspace/JOURNAL.md
fi
```

## TUI Testing with Microsoft TUI Test

This environment includes Microsoft TUI Test pre-installed - a powerful framework for testing ANY terminal application regardless of the language it's written in.

### Quick Start
```bash
# Create config file using the provided alias
tui-test-init  # Creates tui-test.config.ts in current directory

# Create example test using the provided alias
tui-test-example  # Creates example.test.ts in current directory

# Run tests (TUI Test is globally available)
tui-test

# Or use npx to run with options
npx @microsoft/tui-test --trace
```

### Writing TUI Tests
```typescript
import { test, expect } from "@microsoft/tui-test";

test("application lifecycle", async ({ terminal }) => {
    // Start any application (Python, Go, Rust, etc.)
    test.use({ program: { file: "python", args: ["src/main.py"] } });
    
    // Wait for initialization
    await expect(terminal.getByText("Ready")).toBeVisible();
    
    // Test user interactions
    terminal.sendNavigationKey("down");
    terminal.sendNavigationKey("enter");
    
    // Verify behavior
    await expect(terminal.getByText("Selected")).toBeVisible();
});
```

### Common Commands
```bash
# Run with traces
npx @microsoft/tui-test --trace

# View trace
tui-test-trace tui-traces/test-failed.zip

# Run specific test
npx @microsoft/tui-test test-file.ts -g "test name"
```

## Project Templates

### CLI Tool Template
```bash
# Structure for command-line tools
mkdir -p src/{commands,utils,config} tests/{unit,integration,e2e} docs examples
touch src/cli.py  # or main.go, cli.js, etc.
touch src/commands/__init__.py
echo "$(date -Iseconds) [INFO] Created CLI tool structure" >> ~/workspace/JOURNAL.md
```

### Web API Template  
```bash
# Structure for REST/GraphQL APIs
mkdir -p src/{api,models,services,middleware} tests/{unit,integration,e2e} docs migrations
touch src/app.py  # or server.js, main.go, etc.
touch requirements.txt Dockerfile docker-compose.yml
echo "$(date -Iseconds) [INFO] Created Web API structure" >> ~/workspace/JOURNAL.md
```

### TUI Application Template
```bash
# Structure for terminal UIs
mkdir -p src/{ui,components,state} tests/{unit,integration,e2e} docs assets
touch src/app.py  # Main TUI entry point
touch tui-test.config.ts  # For Microsoft TUI Test
echo "$(date -Iseconds) [INFO] Created TUI application structure" >> ~/workspace/JOURNAL.md
```

### Library/Package Template
```bash
# Structure for reusable libraries
mkdir -p src tests/{unit,integration} docs examples benchmarks
touch setup.py pyproject.toml  # or package.json, Cargo.toml, etc.
touch LICENSE CONTRIBUTING.md
echo "$(date -Iseconds) [INFO] Created library/package structure" >> ~/workspace/JOURNAL.md
```

## Error Recovery Strategies

### Common Issues and Solutions

**GitHub repo creation fails**:
```bash
if ! gh repo create PROJECT_NAME; then
    echo "$(date -Iseconds) [ERROR] GitHub creation failed" >> ~/workspace/JOURNAL.md
    echo "$(date -Iseconds) [RECOVERY] Continuing with local development" >> ~/workspace/JOURNAL.md
    echo "$(date -Iseconds) [TODO] Manually create repo later and add remote" >> ~/workspace/JOURNAL.md
fi
```

**Merge conflicts**:
```bash
# When pulling or merging
git pull origin develop
if [ $? -ne 0 ]; then
    echo "$(date -Iseconds) [CONFLICT] Merge conflict detected" >> ~/workspace/JOURNAL.md
    
    # For automated resolution of specific files
    # Accept theirs for generated files
    git checkout --theirs package-lock.json
    
    # Accept ours for config files
    git checkout --ours .env.example
    
    # Manual resolution required for source code
    echo "$(date -Iseconds) [MANUAL] Resolving conflicts in source files" >> ~/workspace/JOURNAL.md
    # Fix conflicts...
    git add .
    git commit -m "fix: resolve merge conflicts"
fi
```

**Test failures after multiple attempts**:
```bash
MAX_ATTEMPTS=3
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if run_tests; then
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "$(date -Iseconds) [RETRY] Test attempt $ATTEMPT of $MAX_ATTEMPTS" >> ~/workspace/JOURNAL.md
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "$(date -Iseconds) [ESCALATION] Tests failing after $MAX_ATTEMPTS attempts" >> ~/workspace/JOURNAL.md
    # Options:
    # 1. Mark test as flaky and skip temporarily
    # 2. Simplify test case
    # 3. Add debugging output
    # 4. Create issue for investigation
fi
```

**Dependency conflicts**:
```bash
# Log the issue
echo "$(date -Iseconds) [ERROR] Dependency conflict: PACKAGE_NAME" >> ~/workspace/JOURNAL.md

# Try resolution strategies
# Python: pip install --force-reinstall
# Node: npm install --force
# Go: go mod tidy
# See language-specific docs for details
```

## Security Considerations

### Local Security Scanning
```bash
# Run security scans locally in the container
# Consult language-specific documentation for appropriate tools:
# - Dependency vulnerability scanning
# - Static code analysis
# - License compliance checking

echo "$(date -Iseconds) [INFO] Running security scans" >> ~/workspace/JOURNAL.md
# [Language-specific security commands from imported docs]
SECURITY_RESULT=$?

if [ $SECURITY_RESULT -ne 0 ]; then
    echo "$(date -Iseconds) [WARNING] Security issues found - review and fix" >> ~/workspace/JOURNAL.md
fi

echo "$(date -Iseconds) [INFO] Security scan completed" >> ~/workspace/JOURNAL.md
```

### Secret Management
```bash
# NEVER commit secrets or sensitive data
# Use environment variables or secret management tools

# Common patterns to add to .gitignore:
echo "
# Secrets and sensitive data
.env
.env.*
*.key
*.pem
*.p12
*.pfx
secrets/
credentials/
config/local.*
" >> .gitignore

# Verify no secrets in staged files
echo "$(date -Iseconds) [INFO] Checking for accidentally staged secrets" >> ~/workspace/JOURNAL.md
git diff --staged --name-only | grep -E '\.(env|key|pem)$' && {
    echo "$(date -Iseconds) [ERROR] Sensitive files detected in staging area" >> ~/workspace/JOURNAL.md
    exit 1
}

echo "$(date -Iseconds) [INFO] Secret management rules configured" >> ~/workspace/JOURNAL.md
```

## Collaboration Patterns

### Multiple Agents
When multiple agents work on the same codebase:
1. Always pull latest changes before starting work
2. Use feature branches to avoid conflicts  
3. Write clear PR descriptions
4. Add [WIP] prefix for work-in-progress PRs
5. Use conventional commits for clear history

### Communication
```bash
# Log important decisions for other agents
echo "$(date -Iseconds) [DECISION] [FOR-AGENT: other-agent] Decision details" >> ~/workspace/JOURNAL.md

# Flag blockers
echo "$(date -Iseconds) [BLOCKER] Waiting for: DESCRIPTION" >> ~/workspace/JOURNAL.md
```

## Critical Rules

### Testing Requirements
1. **Three-Tier Testing Strategy**:
   - Unit tests for isolated component testing
   - Integration tests for component interaction
   - User simulation tests for end-to-end validation

2. **Test Organization**:
   ```
   tests/
   ├── unit/          # Fast, isolated, mocked dependencies
   ├── integration/   # Database, API, file system tests
   └── e2e/          # User simulation, UI automation
   ```

3. **Coverage Requirements**:
   - Unit tests: Minimum 80% code coverage
   - Integration tests: All critical paths covered
   - User simulation: All user workflows tested

4. **Language-Specific Details**: Consult the imported documentation below for:
   - Testing frameworks and tools for your language
   - Specific examples of each test type
   - Performance and property-based testing options
   - Test execution commands and patterns

**Note**: This environment includes Microsoft TUI Test for terminal application testing. Run `tui-test-init` to set up TUI testing for any language.

### DO NOT:
- Create git repositories inside other git repositories
- Skip ANY journal entry
- Push code without ALL tests passing
- Create directories without proper structure
- Use generic test assertions - test actual behavior
- Commit secrets or sensitive data
- Skip error handling and recovery steps

### ALWAYS:
- Use proper environment activation based on language/tool
- Create comprehensive test suites with multiple test cases
- Log EVERY significant action to the journal
- Verify project structure with `tree` command
- Follow language-specific conventions and idioms
- Handle errors gracefully with recovery strategies
- Consider security implications
- Document architectural decisions

### Testing Best Practices:
1. Write tests that describe actual behavior
2. Use appropriate testing frameworks for your language
3. Test both happy path and edge cases
4. Ensure tests are deterministic and reliable
5. Add proper assertions for all expected outcomes
6. Include performance tests for critical paths
7. **IMPORTANT**: Check the imported component documentation below for specialized testing tools available in this environment

## VERIFICATION CHECKLIST
Before considering ANY task complete:
- [ ] Journal has detailed entries for EVERY action
- [ ] Project is in correct directory structure
- [ ] No nested git repositories
- [ ] All test files have actual test implementations
- [ ] Integration tests verify real behavior
- [ ] All tests are passing
- [ ] Documentation is comprehensive
- [ ] PR is created and auto-merge enabled

---
*Note: Language-specific configurations and tooling preferences are available via imports in the project CLAUDE.md file.*

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

