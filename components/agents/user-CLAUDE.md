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

**Create test structure**:
```bash
echo "$(date -Iseconds) [INFO] Creating test suite" >> ~/workspace/JOURNAL.md
```

**Unit Tests**:
```bash
# Create test files based on language conventions
# Python: tests/test_*.py with pytest
# Node.js: tests/*.test.js with jest
# Go: *_test.go files
# Rust: tests/*.rs or #[test] in source
# Ruby: spec/*_spec.rb with rspec

echo "$(date -Iseconds) [INFO] Creating test suite" >> ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [INFO] Created unit tests following LANGUAGE conventions" >> ~/workspace/JOURNAL.md
```

**Integration Tests for TUI/CLI apps**:
```bash
# Create integration tests appropriate for your application type
# Check the "Additional Instructions" section below for specific testing tools available in this environment

# For TUI/CLI applications, ensure you test:
# - Application startup and initialization
# - User input handling and navigation
# - Output verification and state changes
# - Error handling and edge cases

echo "$(date -Iseconds) [INFO] Creating integration tests for TUI/CLI application" >> ~/workspace/JOURNAL.md

# The specific testing approach depends on available tools
# See imported component documentation for detailed examples
```

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
# Run tests using language-specific test runner
# Python: pytest
# Node.js: npm test
# Go: go test
# Rust: cargo test
# Ruby: rspec or bundle exec rake test

echo "$(date -Iseconds) [INFO] Running test suite" >> ../JOURNAL.md
TEST_RESULT=$?
echo "$(date -Iseconds) [INFO] Test suite status: $TEST_RESULT" >> ../JOURNAL.md

if [ $TEST_RESULT -ne 0 ]; then
    echo "$(date -Iseconds) [ERROR] Tests failed" >> ../JOURNAL.md
    # STOP and fix!
fi

# Run integration tests for TUI/CLI apps
echo "$(date -Iseconds) [INFO] Running integration tests" >> ../JOURNAL.md

# Use appropriate testing tools based on what's available
# Check imported component documentation for specific commands
# Common patterns:
# - For Node.js: npm test, jest, mocha
# - For Python: pytest, unittest
# - For Go: go test
# - For Rust: cargo test
# - For specialized TUI testing: see imported testing tools

INTEGRATION_RESULT=$?
echo "$(date -Iseconds) [INFO] Integration test status: $INTEGRATION_RESULT" >> ../JOURNAL.md

# ALL tests must pass before proceeding
echo "$(date -Iseconds) [INFO] All test types must pass before continuing" >> ../JOURNAL.md
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
For all applications:
1. Write comprehensive unit tests using language-appropriate frameworks
2. Create integration tests that verify actual behavior
3. Test both happy paths and edge cases
4. Ensure tests are deterministic and reliable
5. Check the "Additional Instructions" section for specialized testing tools

**Note**: This environment may include specialized testing frameworks. Review the imported component documentation at the end of this file for specific testing tools and their usage patterns.

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
