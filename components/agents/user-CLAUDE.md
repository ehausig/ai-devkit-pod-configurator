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

1. **Ask clarifying questions first**:
   ```bash
   echo "$(date -Iseconds) [DECISION] Clarification needed on: $QUESTION" >> ~/workspace/JOURNAL.md
   ```

2. **Determine project structure**:
   ```bash
   # For single app:
   PROJECT_ROOT="~/workspace/PROJECT_NAME"
   
   # For monorepo:
   PROJECT_ROOT="~/workspace/PROJECT_NAME"
   APP_DIR="$PROJECT_ROOT/APP_NAME"
   
   echo "$(date -Iseconds) [DECISION] Project structure: TYPE chosen because REASON" >> ~/workspace/JOURNAL.md
   ```

3. **Create GitHub repository** (NO EXCEPTIONS):
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
   gh repo create PROJECT_NAME --public --description "PROJECT_DESCRIPTION" || echo "$(date -Iseconds) [ERROR] Failed to create GitHub repo" >> ../JOURNAL.md
   
   # Add remote and push
   git remote add origin https://github.com/USERNAME/PROJECT_NAME.git || true
   git branch -M main
   git push -u origin main
   
   echo "$(date -Iseconds) [MILESTONE] GitHub repo created and pushed: PROJECT_NAME" >> ../JOURNAL.md
   ```

4. **Initialize Git workflow**:
   ```bash
   # Create initial commit
   echo "# PROJECT_NAME" > README.md
   git add README.md
   git commit -m "Initial commit"
   git push -u origin main
   
   # Create develop branch
   git checkout -b develop
   git push -u origin develop
   echo "$(date -Iseconds) [INFO] Created develop branch" >> ~/workspace/JOURNAL.md
   
   # Enable auto-merge
   gh repo edit --enable-auto-merge
   echo "$(date -Iseconds) [INFO] Auto-merge enabled" >> ~/workspace/JOURNAL.md
   ```

5. **Create project structure**:
   ```bash
   # For single app:
   mkdir -p src tests docs
   touch requirements.txt .gitignore
   
   # For monorepo:
   mkdir -p APP_NAME/{src,tests,docs}
   touch APP_NAME/requirements.txt
   
   echo "$(date -Iseconds) [INFO] Project structure created" >> ~/workspace/JOURNAL.md
   ls -la
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
# Run unit tests (expect failure)
pytest tests/test_FEATURE.py -v || echo "Expected failure (TDD)"
echo "$(date -Iseconds) [INFO] Initial test run - Tests failed as expected (TDD)" >> ~/workspace/JOURNAL.md
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
# Run ALL test levels in order
echo "$(date -Iseconds) [INFO] Running complete test suite" >> ../JOURNAL.md

# 1. Unit tests (fastest, run first)
echo "$(date -Iseconds) [INFO] Running unit tests" >> ../JOURNAL.md
# [Language-specific unit test command]
UNIT_RESULT=$?

# 2. Integration tests (slower, run second)
echo "$(date -Iseconds) [INFO] Running integration tests" >> ../JOURNAL.md
# [Language-specific integration test command]
INTEGRATION_RESULT=$?

# 3. User simulation tests (slowest, run last)
echo "$(date -Iseconds) [INFO] Running user simulation tests" >> ../JOURNAL.md
# [Language-specific e2e test command]
E2E_RESULT=$?

# Log results
echo "$(date -Iseconds) [INFO] Test results - Unit: $UNIT_RESULT, Integration: $INTEGRATION_RESULT, E2E: $E2E_RESULT" >> ../JOURNAL.md

if [ $UNIT_RESULT -ne 0 ] || [ $INTEGRATION_RESULT -ne 0 ] || [ $E2E_RESULT -ne 0 ]; then
    echo "$(date -Iseconds) [ERROR] Tests failed - stopping" >> ../JOURNAL.md
    # STOP and fix!
fi

# ALL test levels must pass before proceeding
```

#### 3.7 Fix Until All Tests Pass
```bash
# If any test fails:
echo "$(date -Iseconds) [ERROR] Test failed: TEST_NAME - REASON" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [DECISION] Fix approach: APPROACH" >> ~/workspace/JOURNAL.md
# Fix the code...
echo "$(date -Iseconds) [RESOLUTION] Fixed by: SOLUTION" >> ~/workspace/JOURNAL.md
# Re-run tests and repeat until all pass
```

#### 3.8 Update Documentation
```bash
# Ensure README has all sections
echo "$(date -Iseconds) [INFO] Updating documentation" >> ~/workspace/JOURNAL.md

# README must include:
# - Installation instructions with conda/pip commands
# - Usage examples with screenshots/output
# - Testing instructions
# - Project structure explanation
# - API documentation (if applicable)

echo "$(date -Iseconds) [INFO] Documentation updated - README.md complete" >> ~/workspace/JOURNAL.md
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
git push origin feat/FEATURE_NAME
echo "$(date -Iseconds) [INFO] Pushed to remote" >> ~/workspace/JOURNAL.md

# Create PR
PR_URL=$(gh pr create \
  --title "feat: FEATURE_NAME" \
  --body "## Changes
- List specific changes

## Testing
- ✅ All unit tests pass
- ✅ Integration tests verified

## Screenshots
[Add if applicable]" \
  --base develop)
  
echo "$(date -Iseconds) [MILESTONE] Pull request created: $PR_URL" >> ~/workspace/JOURNAL.md

# Enable auto-merge
gh pr merge --auto --squash --delete-branch
echo "$(date -Iseconds) [INFO] Auto-merge enabled for PR" >> ~/workspace/JOURNAL.md
```

### STEP 4: Session Completion
```bash
# Final summary
echo "$(date -Iseconds) [MILESTONE] Session completed successfully" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] Final test summary:" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] - Test suite: PASSED/FAILED with X tests" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] - Integration tests: PASS/FAIL" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] - Repository: $(git remote get-url origin)" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] - PR: $PR_URL" >> ~/workspace/JOURNAL.md
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

### Key Features
- **Language Agnostic**: Test Python, Go, Rust, Node.js, or any executable
- **Auto-wait**: Automatically waits for terminal to be ready
- **Rich API**: Navigation keys, text matching, snapshots
- **Tracing**: Capture and replay test failures
- **Cross-platform**: Works on Linux, macOS, and Windows

### Common Commands
```bash
# Run with traces
npx @microsoft/tui-test --trace

# View trace
tui-test-trace tui-traces/test-failed.zip

# Run specific test
npx @microsoft/tui-test test-file.ts -g "test name"
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

### ALWAYS:
- Use proper environment activation based on language/tool
- Create comprehensive test suites with multiple test cases
- Log EVERY significant action to the journal
- Verify project structure with `tree` command
- Follow language-specific conventions and idioms

### Testing Best Practices:
1. Write tests that describe actual behavior
2. Use appropriate testing frameworks for your language
3. Test both happy path and edge cases
4. Ensure tests are deterministic and reliable
5. Add proper assertions for all expected outcomes
6. **IMPORTANT**: Check the imported component documentation below for specialized testing tools available in this environment

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
