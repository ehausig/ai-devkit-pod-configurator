#!/bin/bash
# Test integration scenarios with real tools and multi-project workflows

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Setup test journal location
export TEST_JOURNAL="/tmp/test-journal-$$.md"
export JOURNAL_FILE="$TEST_JOURNAL"

# Test git integration
test_git_operations() {
  # Create a test repository
  local test_repo="/tmp/test-git-$$"
  mkdir -p "$test_repo"
  cd "$test_repo"
  
  # Initialize git
  git init >/dev/null 2>&1
  git config user.name "Test User" >/dev/null 2>&1
  git config user.email "test@example.com" >/dev/null 2>&1
  
  # Simulate DEVELOPER creating files and committing
  echo "# Test Project" > README.md
  git add README.md
  git commit -m "Initial commit" >/dev/null 2>&1
  
  # Create feature branch
  git checkout -b feat/test-feature >/dev/null 2>&1
  echo "def test(): pass" > test.py
  git add test.py
  git commit -m "Add test file" >/dev/null 2>&1
  
  # Log git operations
  echo "$(date -Iseconds) [DEVELOPER:CONTEXT] Created feature branch feat/test-feature" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [DEVELOPER:MEMORY] Git configured with test credentials" >> "$TEST_JOURNAL"
  
  # Verify git state
  local current_branch=$(git branch --show-current)
  assert_equals "feat/test-feature" "$current_branch" "Should be on feature branch"
  
  local commit_count=$(git rev-list --count HEAD)
  assert_equals "2" "$commit_count" "Should have 2 commits"
  
  # Cleanup - return to original directory first
  cd - >/dev/null
  rm -rf "$test_repo"
}

# Test multi-language project support
test_multi_language_support() {
  local test_dir="/tmp/test-multi-lang-$$"
  mkdir -p "$test_dir"
  cd "$test_dir"
  
  # Python project
  mkdir -p python-service
  cd python-service
  cat > requirements.txt << EOF
fastapi==0.104.1
pytest==7.4.3
EOF
  
  echo "$(date -Iseconds) [ARCHITECT:DECISION] Chose Python for API service" >> "$TEST_JOURNAL"
  assert_file_exists "requirements.txt" "Python requirements created"
  
  cd ..
  
  # Node.js project
  mkdir -p nodejs-frontend
  cd nodejs-frontend
  cat > package.json << EOF
{
  "name": "frontend",
  "version": "1.0.0",
  "dependencies": {
    "react": "^18.0.0"
  }
}
EOF
  
  echo "$(date -Iseconds) [ARCHITECT:DECISION] Chose React for frontend" >> "$TEST_JOURNAL"
  assert_file_exists "package.json" "Node.js package.json created"
  
  cd ..
  
  # Go project
  mkdir -p go-worker
  cd go-worker
  cat > go.mod << EOF
module worker

go 1.21
EOF
  
  echo "$(date -Iseconds) [ARCHITECT:DECISION] Chose Go for worker service" >> "$TEST_JOURNAL"
  assert_file_exists "go.mod" "Go module created"
  
  # Verify multi-language setup
  local decisions=$(grep "ARCHITECT:DECISION" "$TEST_JOURNAL" | wc -l)
  assert_equals "3" "$decisions" "Should have decisions for all languages"
  
  # Cleanup - return to original directory first
  cd "$TEST_ORIGINAL_DIR"
  rm -rf "$test_dir"
}

# Test actual tool execution
test_tool_execution() {
  local test_dir="/tmp/test-tools-$$"
  mkdir -p "$test_dir"
  cd "$test_dir"
  
  # Test various tool commands
  local tools_tested=0
  
  # Test git
  if command -v git >/dev/null 2>&1; then
    git init >/dev/null 2>&1
    ((tools_tested++))
    assert_file_exists ".git" "Git repository initialized"
  fi
  
  # Test npm (if available)
  if command -v npm >/dev/null 2>&1; then
    echo '{"name":"test"}' > package.json
    # Don't actually run npm install in tests
    ((tools_tested++))
    assert_file_exists "package.json" "NPM package.json created"
  fi
  
  # Test python
  if command -v python3 >/dev/null 2>&1; then
    echo "print('test')" > test.py
    python3 test.py >/dev/null 2>&1
    local py_result=$?
    ((tools_tested++))
    assert_equals "0" "$py_result" "Python script executed"
  fi
  
  # At least some tools should be available
  if [ $tools_tested -gt 0 ]; then
    assert_equals "tested" "tested" "Tested $tools_tested tools"
  else
    assert_equals "none" "some" "No tools available for testing"
  fi
  
  # Cleanup
  cd "$TEST_ORIGINAL_DIR"
  rm -rf "$test_dir"
}

# Test project structure creation
test_project_structure_creation() {
  local test_dir="/tmp/test-structure-$$"
  mkdir -p "$test_dir"
  cd "$test_dir"
  
  # Create standard project structure
  local dirs=(
    "src"
    "tests"
    "docs"
    "scripts"
    ".github/workflows"
    "config"
  )
  
  for dir in "${dirs[@]}"; do
    mkdir -p "$dir"
  done
  
  # Create standard files
  touch README.md
  touch .gitignore
  touch LICENSE
  touch CHANGELOG.md
  touch Makefile
  
  # Verify structure
  for dir in "${dirs[@]}"; do
    assert_file_exists "$dir" "Directory $dir should exist"
  done
  
  assert_file_exists "README.md" "README should exist"
  assert_file_exists ".gitignore" "gitignore should exist"
  
  # Log structure creation
  echo "$(date -Iseconds) [DEVELOPER:CONTEXT] Created project structure with $(find . -type d | wc -l) directories" >> "$TEST_JOURNAL"
  
  # Cleanup
  cd "$TEST_ORIGINAL_DIR"
  rm -rf "$test_dir"
}

# Test CI/CD configuration
test_cicd_configuration() {
  local test_dir="/tmp/test-cicd-$$"
  mkdir -p "$test_dir/.github/workflows"
  cd "$test_dir"
  
  # Create GitHub Actions workflow
  cat > .github/workflows/ci.yml << 'EOF'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: npm test
EOF
  
  assert_file_exists ".github/workflows/ci.yml" "CI workflow created"
  
  # Create GitLab CI configuration
  cat > .gitlab-ci.yml << 'EOF'
stages:
  - test
  - build
  - deploy

test:
  stage: test
  script:
    - npm test
EOF
  
  assert_file_exists ".gitlab-ci.yml" "GitLab CI created"
  
  echo "$(date -Iseconds) [ARCHITECT:DECISION] Configured CI/CD for GitHub Actions and GitLab" >> "$TEST_JOURNAL"
  
  # Cleanup
  cd "$TEST_ORIGINAL_DIR"
  rm -rf "$test_dir"
}

# Test environment configuration
test_environment_configuration() {
  local test_dir="/tmp/test-env-$$"
  mkdir -p "$test_dir"
  cd "$test_dir"
  
  # Create environment files
  cat > .env.example << EOF
DATABASE_URL=postgresql://user:pass@localhost/db
REDIS_URL=redis://localhost:6379
API_KEY=your-api-key-here
DEBUG=false
EOF
  
  cat > .env.test << EOF
DATABASE_URL=postgresql://test:test@localhost/test_db
REDIS_URL=redis://localhost:6379/1
API_KEY=test-api-key
DEBUG=true
EOF
  
  assert_file_exists ".env.example" "Example env file created"
  assert_file_exists ".env.test" "Test env file created"
  
  # Create docker-compose for local development
  cat > docker-compose.yml << EOF
version: '3.8'
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: dev_db
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
  redis:
    image: redis:7
EOF
  
  assert_file_exists "docker-compose.yml" "Docker compose created"
  
  echo "$(date -Iseconds) [DEVELOPER:MEMORY] Local dev environment uses Docker Compose" >> "$TEST_JOURNAL"
  
  # Cleanup
  cd "$TEST_ORIGINAL_DIR"
  rm -rf "$test_dir"
}

# Test documentation generation
test_documentation_generation() {
  local test_dir="/tmp/test-docs-$$"
  mkdir -p "$test_dir/docs"
  cd "$test_dir"
  
  # Create various documentation files
  cat > docs/api.md << EOF
# API Documentation

## Endpoints

### GET /health
Returns the health status of the service.

### POST /users
Creates a new user.
EOF
  
  cat > docs/architecture.md << EOF
# Architecture Overview

## System Components
- API Service (Python/FastAPI)
- Frontend (React)
- Database (PostgreSQL)
- Cache (Redis)
EOF
  
  cat > docs/deployment.md << EOF
# Deployment Guide

## Prerequisites
- Docker
- Kubernetes
- Helm

## Steps
1. Build images
2. Push to registry
3. Deploy with Helm
EOF
  
  # Verify documentation
  local doc_count=$(find docs -name "*.md" | wc -l)
  assert_equals "3" "$doc_count" "Should have 3 documentation files"
  
  echo "$(date -Iseconds) [DEVELOPER:CONTEXT] Generated $doc_count documentation files" >> "$TEST_JOURNAL"
  
  # Cleanup
  cd "$TEST_ORIGINAL_DIR"
  rm -rf "$test_dir"
}

# Test dependency management
test_dependency_management() {
  local test_dir="/tmp/test-deps-$$"
  mkdir -p "$test_dir"
  cd "$test_dir"
  
  # Python dependencies
  cat > requirements.txt << EOF
# Web framework
fastapi==0.104.1
uvicorn==0.24.0

# Database
sqlalchemy==2.0.23
alembic==1.12.1

# Testing
pytest==7.4.3
pytest-cov==4.1.0

# Linting
black==23.11.0
flake8==6.1.0
EOF
  
  # Node.js dependencies
  cat > package.json << EOF
{
  "name": "test-project",
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "eslint": "^8.54.0"
  }
}
EOF
  
  # Verify dependency files
  assert_file_exists "requirements.txt" "Python dependencies defined"
  assert_file_exists "package.json" "Node.js dependencies defined"
  
  # Count total dependencies
  local py_deps=$(grep -E "^[a-zA-Z]" requirements.txt | wc -l)
  local npm_deps=4  # Hardcoded since we can't easily parse JSON in bash
  
  echo "$(date -Iseconds) [DEVELOPER:MEMORY] Project has $py_deps Python and $npm_deps Node.js dependencies" >> "$TEST_JOURNAL"
  
  # Cleanup
  cd "$TEST_ORIGINAL_DIR"
  rm -rf "$test_dir"
}

# Test cross-persona integration
test_cross_persona_integration() {
  # Simulate a complete feature development across all personas
  
  # ARCHITECT designs
  echo "$(date -Iseconds) [ARCHITECT:DECISION] Microservices architecture with 3 services" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [ARCHITECT:MEMORY] Each service has its own repository" >> "$TEST_JOURNAL"
  
  # DEVELOPER implements
  echo "$(date -Iseconds) [DEVELOPER:CONTEXT] Implementing user service" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [DEVELOPER:CONTEXT] Implementing order service" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [DEVELOPER:CONTEXT] Implementing notification service" >> "$TEST_JOURNAL"
  
  # QA tests
  echo "$(date -Iseconds) [QA:CONTEXT] Integration tests across all services" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [QA:ISSUE] Service communication timeout under load" >> "$TEST_JOURNAL"
  
  # DEVELOPER fixes
  echo "$(date -Iseconds) [DEVELOPER:RESOLVED] Increased timeout and added retry logic" >> "$TEST_JOURNAL"
  
  # REVIEWER reviews
  echo "$(date -Iseconds) [REVIEWER:CONTEXT] Reviewing microservices implementation" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [REVIEWER:APPROVED] All services follow design patterns" >> "$TEST_JOURNAL"
  
  # MERGER deploys
  echo "$(date -Iseconds) [MERGER:CONTEXT] Deploying services to Kubernetes" >> "$TEST_JOURNAL"
  echo "$(date -Iseconds) [MERGER:MEMORY] Version 1.0.0 deployed to production" >> "$TEST_JOURNAL"
  
  # Verify cross-persona flow
  local architect_entries=$(grep "ARCHITECT:" "$TEST_JOURNAL" | wc -l)
  local developer_entries=$(grep "DEVELOPER:" "$TEST_JOURNAL" | wc -l)
  local qa_entries=$(grep "QA:" "$TEST_JOURNAL" | wc -l)
  local reviewer_entries=$(grep "REVIEWER:" "$TEST_JOURNAL" | wc -l)
  local merger_entries=$(grep "MERGER:" "$TEST_JOURNAL" | wc -l)
  
  assert_equals "2" "$architect_entries" "ARCHITECT made decisions"
  assert_equals "4" "$developer_entries" "DEVELOPER implemented and fixed"
  assert_equals "2" "$qa_entries" "QA tested and found issues"
  assert_equals "2" "$reviewer_entries" "REVIEWER reviewed and approved"
  assert_equals "2" "$merger_entries" "MERGER deployed"
}

# Initialize test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Run all tests
run_tests

# The test framework reports the summary
exit $?
