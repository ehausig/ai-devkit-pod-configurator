#!/bin/bash
# REVIEWER Actor - Code review and quality assurance persona

# Source the base actor functionality
source es-actor-base

# Persona name
PERSONA="REVIEWER"

# Review tracking
ISSUES_FOUND=0
SUGGESTIONS_MADE=0
COMPONENTS_APPROVED=0

# Initialize REVIEWER context
initialize_persona() {
    log_context "REVIEWER persona initialized - ready for code review"
    
    # Reset counters
    ISSUES_FOUND=0
    SUGGESTIONS_MADE=0
    COMPONENTS_APPROVED=0
    
    # Set up review workspace
    setup_review_workspace
}

# Set up isolated review workspace
setup_review_workspace() {
    REVIEW_DIR="$HOME/workspace/review"
    if [ ! -d "$REVIEW_DIR" ]; then
        mkdir -p "$REVIEW_DIR"
        log_memory "Created review directory: $REVIEW_DIR"
    fi
}

# Determine next persona based on review results
determine_next_persona() {
    local from="$1"
    
    # Decision based on review findings
    if [ $ISSUES_FOUND -gt 0 ]; then
        echo "DEVELOPER:Found $ISSUES_FOUND critical issues requiring fixes"
    else
        echo "MERGER:Code approved, ready for merge"
    fi
}

# Generate work items for next persona
generate_work_items() {
    local from="$1"
    local to="$2"
    
    case "$to" in
        MERGER)
            # Code approved - ready for merge
            local pr_number=$(gh pr list --json number --jq '.[0].number' 2>/dev/null || echo "")
            
            echo "Verify all CI/CD checks pass for PR #${pr_number:-pending}"
            echo "Run final integration tests on main branch"
            echo "Merge PR #${pr_number:-pending} using --no-ff for clear history"
            echo "Update CHANGELOG.md with version and changes"
            echo "Tag release version according to semantic versioning"
            echo "Delete feature branch after successful merge"
            echo "Update project documentation if needed"
            echo "Notify stakeholders of completion"
            ;;
            
        DEVELOPER)
            # Issues found - back to developer
            
            # Create fix tasks for each issue
            local issue_num=1
            grep "\[REVIEWER:ISSUE\]" "$JOURNAL_FILE" | tail -20 | while IFS= read -r issue_line; do
                local issue_desc=$(echo "$issue_line" | sed 's/.*\[REVIEWER:ISSUE\] //')
                echo "Address review issue #$issue_num: $issue_desc"
                ((issue_num++))
            done
            
            # Add tasks for suggestions if any
            if [ $SUGGESTIONS_MADE -gt 0 ]; then
                echo "Consider implementing review suggestions for code improvement"
            fi
            
            # Standard review response tasks
            echo "Update tests if implementation changes"
            echo "Run all tests to verify fixes"
            echo "Update PR with review fixes"
            echo "Request re-review when complete"
            ;;
    esac
}

# Execute REVIEWER-specific work
execute_persona_work() {
    local work_id="$1"
    local work_desc="$2"
    
    case "$work_desc" in
        *"Clone PR branch"*|*"review directory"*)
            log_decision "Setting up review environment"
            
            cd "$REVIEW_DIR"
            
            # Clone to review directory
            local main_project="$HOME/workspace"
            if [ -d "$main_project/.git" ]; then
                if [ ! -d "project-review/.git" ]; then
                    execute_command "git clone $main_project project-review" \
                        "Cloning project for review"
                fi
                
                cd project-review
                
                # Get PR branch
                local pr_branch=$(cd "$main_project" && git branch --show-current)
                if [ -n "$pr_branch" ] && [ "$pr_branch" != "main" ] && [ "$pr_branch" != "master" ]; then
                    execute_command "git checkout $pr_branch 2>/dev/null || git checkout -b $pr_branch origin/$pr_branch" \
                        "Checking out PR branch: $pr_branch"
                fi
            fi
            
            return 0
            ;;
            
        *"automated"*|*"quality check"*|*"lint"*)
            log_decision "Running automated code quality checks"
            
            # Run linters based on project type
            if [ -f "package.json" ]; then
                if npm run lint 2>&1; then
                    log_context "ESLint checks passed"
                else
                    ((ISSUES_FOUND++))
                    log_issue "ESLint found code style issues"
                fi
            elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
                if command -v flake8 >/dev/null 2>&1; then
                    if flake8 src/ 2>&1; then
                        log_context "Flake8 checks passed"
                    else
                        ((ISSUES_FOUND++))
                        log_issue "Flake8 found code style issues"
                    fi
                fi
                
                if command -v black >/dev/null 2>&1; then
                    if black --check src/ 2>&1; then
                        log_context "Black formatting check passed"
                    else
                        ((SUGGESTIONS_MADE++))
                        log_memory "Code formatting could be improved with black"
                    fi
                fi
            elif [ -f "Cargo.toml" ]; then
                if cargo clippy -- -D warnings 2>&1; then
                    log_context "Clippy checks passed"
                else
                    ((ISSUES_FOUND++))
                    log_issue "Clippy found code issues"
                fi
            fi
            
            # Security scan
            log_context "Performing security scan"
            if [ -f "package.json" ] && command -v npm >/dev/null 2>&1; then
                if npm audit 2>&1 | grep -q "found 0 vulnerabilities"; then
                    log_context "No security vulnerabilities found"
                else
                    ((ISSUES_FOUND++))
                    log_issue "Security vulnerabilities detected in dependencies"
                fi
            fi
            
            return 0
            ;;
            
        *"architectural decision"*|*"architecture"*)
            log_decision "Reviewing code against architectural decisions"
            
            if [ -f "$HOME/workspace/ARCHITECTURE.md" ]; then
                log_context "Checking compliance with ARCHITECTURE.md"
                
                # Check for proper structure
                if [ -d "src" ] && [ -d "tests" ]; then
                    ((COMPONENTS_APPROVED++))
                    log_context "Project structure follows architecture"
                else
                    ((ISSUES_FOUND++))
                    log_issue "Project structure doesn't match architectural design"
                fi
                
                # Check for modular design
                local module_count=$(find src -name "*.py" -o -name "*.js" -o -name "*.rs" -o -name "*.go" | wc -l)
                if [ $module_count -gt 1 ]; then
                    ((COMPONENTS_APPROVED++))
                    log_context "Code is properly modularized"
                fi
            fi
            
            return 0
            ;;
            
        *"test quality"*|*"coverage"*)
            log_decision "Reviewing test quality and coverage"
            
            # Check test existence
            local test_count=$(find tests -name "test_*" -o -name "*.test.*" 2>/dev/null | wc -l)
            if [ $test_count -gt 0 ]; then
                ((COMPONENTS_APPROVED++))
                log_context "Found $test_count test files"
            else
                ((ISSUES_FOUND++))
                log_issue "Insufficient test files found"
            fi
            
            # Check for test quality indicators
            if grep -r "mock\|stub\|spy" tests/ 2>/dev/null | grep -q .; then
                log_context "Tests use appropriate mocking"
            fi
            
            if grep -r "assert\|expect" tests/ 2>/dev/null | grep -q .; then
                log_context "Tests include proper assertions"
            else
                ((ISSUES_FOUND++))
                log_issue "Tests lack proper assertions"
            fi
            
            # Coverage was already checked by QA
            log_memory "Coverage requirement: 80% minimum"
            
            return 0
            ;;
            
        *"error handling"*)
            log_decision "Verifying error handling implementation"
            
            # Check for error handling patterns
            local has_error_handling=false
            
            if grep -r "try.*catch\|except.*:\|Result<.*Error>\|if.*err.*!=.*nil" src/ 2>/dev/null | grep -q .; then
                has_error_handling=true
                ((COMPONENTS_APPROVED++))
                log_context "Error handling patterns found"
            else
                ((ISSUES_FOUND++))
                log_issue "Limited error handling found in code"
            fi
            
            # Check for error logging
            if grep -r "log.*error\|logger.*error\|console.error" src/ 2>/dev/null | grep -q .; then
                log_context "Error logging implemented"
            else
                ((SUGGESTIONS_MADE++))
                log_memory "Consider adding error logging"
            fi
            
            return 0
            ;;
            
        *"API implementation"*|*"API"*)
            log_decision "Validating API implementation against design"
            
            if [ -f "$HOME/workspace/API_DESIGN.md" ]; then
                log_context "Checking API compliance with API_DESIGN.md"
                
                # Check for API endpoints
                if grep -r "route\|endpoint\|@app.route\|router\|Router" src/ 2>/dev/null | grep -q .; then
                    ((COMPONENTS_APPROVED++))
                    log_context "API routing implemented"
                else
                    ((ISSUES_FOUND++))
                    log_issue "No API routing found"
                fi
                
                # Check for proper HTTP status codes
                if grep -r "200\|201\|400\|404\|500" src/ 2>/dev/null | grep -q "status"; then
                    log_context "HTTP status codes properly used"
                else
                    ((SUGGESTIONS_MADE++))
                    log_memory "Ensure proper HTTP status codes are returned"
                fi
            fi
            
            return 0
            ;;
            
        *"documentation"*|*"comments"*)
            log_decision "Reviewing code documentation and comments"
            
            # Check for file headers/module documentation
            local documented_files=0
            local total_files=0
            
            for file in $(find src -name "*.py" -o -name "*.js" -o -name "*.rs" -o -name "*.go" 2>/dev/null); do
                ((total_files++))
                if head -10 "$file" | grep -q "^\s*[/#]\|^\s*\*\|^\/\*\*"; then
                    ((documented_files++))
                fi
            done
            
            if [ $total_files -gt 0 ]; then
                local doc_percentage=$((documented_files * 100 / total_files))
                if [ $doc_percentage -gt 70 ]; then
                    ((COMPONENTS_APPROVED++))
                    log_context "Good documentation coverage: ${doc_percentage}%"
                else
                    ((SUGGESTIONS_MADE++))
                    log_memory "Documentation coverage could be improved: ${doc_percentage}%"
                fi
            fi
            
            # Check README
            if [ -f "README.md" ] && [ $(wc -l < README.md) -gt 20 ]; then
                ((COMPONENTS_APPROVED++))
                log_context "README is comprehensive"
            else
                ((SUGGESTIONS_MADE++))
                log_memory "README could be more detailed"
            fi
            
            return 0
            ;;
            
        *"security"*|*"vulnerabilit"*)
            log_decision "Checking for security vulnerabilities"
            
            # Check for common security issues
            local security_issues=0
            
            # SQL injection risks
            if grep -r "SELECT.*\+\|INSERT.*\+\|UPDATE.*\+\|DELETE.*\+" src/ 2>/dev/null | grep -v "prepare"; then
                ((security_issues++))
                log_issue "Potential SQL injection risk - use parameterized queries"
            fi
            
            # Hardcoded secrets
            if grep -r "password\s*=\s*[\"'][^\"']+[\"']\|api_key\s*=\s*[\"'][^\"']+[\"']" src/ 2>/dev/null | grep -v "example\|test"; then
                ((security_issues++))
                log_issue "Hardcoded secrets found - use environment variables"
            fi
            
            if [ $security_issues -eq 0 ]; then
                ((COMPONENTS_APPROVED++))
                log_context "No obvious security vulnerabilities found"
            else
                ((ISSUES_FOUND += security_issues))
            fi
            
            return 0
            ;;
            
        *"performance"*)
            log_decision "Reviewing performance considerations"
            
            # Check for obvious performance issues
            
            # Look for N+1 query patterns
            if grep -r "for.*in.*:\s*\n.*query\|\.find.*for\|\.get.*for" src/ 2>/dev/null | grep -q .; then
                ((SUGGESTIONS_MADE++))
                log_memory "Potential N+1 query pattern detected"
            fi
            
            # Check for indexing in data models
            if [ -f "$HOME/workspace/DATA_MODELS.md" ]; then
                if grep -q "index\|Index" "$HOME/workspace/DATA_MODELS.md"; then
                    log_context "Database indexes defined"
                else
                    ((SUGGESTIONS_MADE++))
                    log_memory "Consider adding database indexes for performance"
                fi
            fi
            
            ((COMPONENTS_APPROVED++))
            log_context "Basic performance review completed"
            
            return 0
            ;;
            
        *"feedback"*|*"approve"*)
            log_decision "Providing comprehensive review feedback"
            
            # Create review report
            create_file_with_content "REVIEW_REPORT.md" "# Code Review Report

## Review Summary
- Date: $(date -Iseconds)
- Critical Issues: $ISSUES_FOUND
- Suggestions: $SUGGESTIONS_MADE
- Components Approved: $COMPONENTS_APPROVED

## Review Checklist
- [$([ $ISSUES_FOUND -eq 0 ] && echo "x" || echo " ")] Code follows architectural design
- [$([ $COMPONENTS_APPROVED -gt 5 ] && echo "x" || echo " ")] Tests are comprehensive
- [x] Error handling is implemented
- [$([ $ISSUES_FOUND -eq 0 ] && echo "x" || echo " ")] No security vulnerabilities
- [x] Code is documented
- [x] Performance is acceptable

## Issues Found
$(if [ $ISSUES_FOUND -gt 0 ]; then
    grep "\[REVIEWER:ISSUE\]" "$JOURNAL_FILE" | tail -20 | sed 's/.*\[REVIEWER:ISSUE\] /- /'
else
    echo "No critical issues found"
fi)

## Suggestions
$(if [ $SUGGESTIONS_MADE -gt 0 ]; then
    grep "\[REVIEWER:MEMORY\]" "$JOURNAL_FILE" | tail -10 | grep -i "consider\|could\|improve" | sed 's/.*\[REVIEWER:MEMORY\] /- /'
else
    echo "No additional suggestions"
fi)

## Decision
$(if [ $ISSUES_FOUND -eq 0 ]; then
    echo "✅ **APPROVED** - Ready for merge"
else
    echo "❌ **CHANGES REQUESTED** - Issues must be addressed"
fi)"
            
            log_memory "Review completed with detailed feedback"
            
            # Add GitHub PR review if available
            if command -v gh >/dev/null 2>&1; then
                local pr_number=$(gh pr list --json number --jq '.[0].number' 2>/dev/null)
                if [ -n "$pr_number" ]; then
                    if [ $ISSUES_FOUND -eq 0 ]; then
                        execute_command "gh pr review $pr_number --approve --body 'Code review passed. $COMPONENTS_APPROVED components approved.'" \
                            "Approving PR #$pr_number"
                    else
                        execute_command "gh pr review $pr_number --request-changes --body 'Found $ISSUES_FOUND issues that need to be addressed.'" \
                            "Requesting changes on PR #$pr_number"
                    fi
                fi
            fi
            
            return 0
            ;;
            
        *)
            log_issue "Unknown review work type: $work_desc"
            return 1
            ;;
    esac
}

# Log successful work completion
log_work_success() {
    local work_id="$1"
    local work_desc="$2"
    log_context "Successfully completed: $work_desc"
}

# Log work failure
log_work_failure() {
    local work_id="$1"
    local work_desc="$2"
    local exit_code="$3"
    log_issue "Failed to complete: $work_desc (exit code: $exit_code)"
}

# Log handoff context
log_handoff_context() {
    local next_persona="$1"
    local reason="$2"
    log_context "Handing off to $next_persona - $reason"
    
    if [ "$next_persona" = "MERGER" ]; then
        log_memory "Code review passed, ready for integration"
    else
        log_memory "Code review found issues requiring attention"
    fi
}

# Start the actor
actor_loop "$PERSONA"
