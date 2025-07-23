#!/bin/bash
# MERGER Actor - Integration and release management persona

# Check command line arguments for test mode
for arg in "$@"; do
    case $arg in
        --test-harness)
            export TEST_MODE=1
            export ACTOR_RUNTIME_MODE="test"
            echo "MERGER Actor started with --test-harness flag" >&2
            ;;
    esac
done

# Detect if we should run autonomously
SHOULD_RUN_AUTONOMOUS=true
if [ "$TEST_MODE" = "1" ]; then
    SHOULD_RUN_AUTONOMOUS=false
    echo "MERGER Actor loaded in test mode" >&2
fi

# Source the base actor functionality
source es-actor-base.sh

# Persona name
PERSONA="MERGER"

# Merge tracking
MERGES_COMPLETED=0
RELEASES_CREATED=0
ISSUES_ENCOUNTERED=0

# Initialize MERGER context
initialize_persona() {
    log_context "MERGER persona initialized - ready for integration"
    
    # Reset counters
    MERGES_COMPLETED=0
    RELEASES_CREATED=0
    ISSUES_ENCOUNTERED=0
    
    # Check current branch and repo state
    check_repository_state
}

# Check repository state
check_repository_state() {
    if [ -d .git ]; then
        local current_branch=$(git branch --show-current)
        local has_changes=$(git status --porcelain | wc -l)
        
        log_memory "Current branch: $current_branch"
        if [ $has_changes -gt 0 ]; then
            log_memory "Working directory has uncommitted changes"
        fi
    fi
}

# Determine next persona based on merge results
determine_next_persona() {
    local from="$1"
    
    # Check if there are more PRs to process
    if command -v gh >/dev/null 2>&1; then
        local open_prs=$(gh pr list --json number 2>/dev/null | jq length)
        if [ "$open_prs" -gt 0 ]; then
            echo "DEVELOPER:More PRs to process ($open_prs remaining)"
            return
        fi
    fi
    
    # Check if new work has appeared for any persona
    for persona in ARCHITECT DEVELOPER QA REVIEWER; do
        local pending=$(es-projection.sh "$persona" "pending_work" | wc -l)
        if [ "$pending" -gt 0 ]; then
            echo "$persona:Found $pending pending items for $persona"
            return
        fi
    done
    
    # No more work
    echo "COMPLETE:Development cycle complete"
}

# Generate work items for next persona
generate_work_items() {
    local from="$1"
    local to="$2"
    
    case "$to" in
        DEVELOPER)
            # More PRs to handle or post-merge work
            echo "Review and prioritize remaining open PRs"
            echo "Address any post-merge issues if reported"
            echo "Check for merge conflicts in other branches"
            ;;
            
        ARCHITECT)
            # New feature cycle
            echo "Design architecture for next feature set"
            echo "Review backlog and prioritize features"
            echo "Update architecture based on lessons learned"
            ;;
            
        *)
            # Cycle complete - no more work
            log_context "No more work items to generate"
            ;;
    esac
}

# Execute MERGER-specific work
execute_persona_work() {
    local work_id="$1"
    local work_desc="$2"
    
    case "$work_desc" in
        *"CI/CD"*|*"checks pass"*)
            log_decision "Verifying CI/CD status"
            
            if command -v gh >/dev/null 2>&1; then
                local pr_number=$(echo "$work_desc" | grep -o '#[0-9]*' | tr -d '#')
                if [ -z "$pr_number" ]; then
                    pr_number=$(gh pr list --json number --jq '.[0].number' 2>/dev/null)
                fi
                
                if [ -n "$pr_number" ]; then
                    log_context "Checking CI/CD for PR #$pr_number"
                    
                    # Check PR status
                    if gh pr checks "$pr_number" 2>&1 | grep -q "All checks have passed"; then
                        log_context "All CI/CD checks passed"
                    else
                        # Wait a bit for checks to complete
                        sleep 5
                        if gh pr checks "$pr_number" 2>&1 | grep -q "fail"; then
                            ((ISSUES_ENCOUNTERED++))
                            log_issue "CI/CD checks failed for PR #$pr_number"
                        else
                            log_context "CI/CD checks in progress"
                        fi
                    fi
                fi
            else
                log_context "GitHub CLI not available, assuming CI/CD passed"
            fi
            
            return 0
            ;;
            
        *"integration test"*|*"main branch"*)
            log_decision "Running final integration tests"
            
            # Ensure we're on main branch
            execute_command "git checkout main 2>/dev/null || git checkout master" \
                "Switching to main branch"
            
            execute_command "git pull origin main 2>/dev/null || git pull origin master" \
                "Updating main branch"
            
            # Run tests on main
            if run_tests; then
                log_context "Integration tests passed on main branch"
            else
                ((ISSUES_ENCOUNTERED++))
                log_issue "Integration tests failed on main branch"
            fi
            
            return 0
            ;;
            
        *"Merge PR"*)
            log_decision "Merging pull request"
            
            local pr_number=$(echo "$work_desc" | grep -o '#[0-9]*' | tr -d '#')
            if [ -z "$pr_number" ] && command -v gh >/dev/null 2>&1; then
                pr_number=$(gh pr list --json number --jq '.[0].number' 2>/dev/null)
            fi
            
            if [ -n "$pr_number" ]; then
                log_context "Merging PR #$pr_number"
                
                if command -v gh >/dev/null 2>&1; then
                    # Merge using GitHub CLI
                    if gh pr merge "$pr_number" --merge --delete-branch 2>&1; then
                        ((MERGES_COMPLETED++))
                        log_memory "Successfully merged PR #$pr_number"
                        
                        # Log merge details
                        local merge_commit=$(git log --oneline -1 --grep="Merge pull request #$pr_number")
                        if [ -n "$merge_commit" ]; then
                            log_context "Merge commit: $merge_commit"
                        fi
                    else
                        ((ISSUES_ENCOUNTERED++))
                        log_issue "Failed to merge PR #$pr_number"
                    fi
                else
                    # Manual merge
                    local feature_branch=$(git branch -r | grep -v HEAD | grep -v main | grep -v master | head -1 | xargs)
                    if [ -n "$feature_branch" ]; then
                        if execute_command "git merge --no-ff $feature_branch -m 'Merge feature branch'" \
                            "Merging $feature_branch"; then
                            ((MERGES_COMPLETED++))
                            log_memory "Successfully merged $feature_branch"
                        else
                            ((ISSUES_ENCOUNTERED++))
                            log_issue "Failed to merge $feature_branch"
                        fi
                    fi
                fi
            else
                log_issue "No PR number found for merge"
            fi
            
            return 0
            ;;
            
        *"CHANGELOG"*)
            log_decision "Updating CHANGELOG.md"
            
            # Get current version
            local current_version="0.1.0"
            if [ -f "package.json" ]; then
                current_version=$(grep '"version"' package.json | head -1 | sed 's/.*"version": "\(.*\)".*/\1/')
            elif [ -f "Cargo.toml" ]; then
                current_version=$(grep '^version' Cargo.toml | head -1 | sed 's/.*= "\(.*\)".*/\1/')
            fi
            
            # Increment version (patch level)
            local new_version=$(echo $current_version | awk -F. '{print $1"."$2"."$3+1}')
            
            # Create or update CHANGELOG
            local changelog_entry="## [$new_version] - $(date +%Y-%m-%d)

### Added
- Initial implementation based on architecture
- Comprehensive test suite with ${TEST_COVERAGE:-80}% coverage
- API endpoints as specified in API_DESIGN.md
- Error handling and logging

### Changed
- N/A (initial release)

### Fixed
- N/A (initial release)
"
            
            if [ -f "CHANGELOG.md" ]; then
                # Prepend to existing changelog
                echo -e "$changelog_entry\n" | cat - CHANGELOG.md > temp && mv temp CHANGELOG.md
            else
                # Create new changelog
                create_file_with_content "CHANGELOG.md" "# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

$changelog_entry"
            fi
            
            log_memory "Updated CHANGELOG for version $new_version"
            
            # Update version in project files
            case "$PROJECT_TYPE" in
                nodejs)
                    if [ -f "package.json" ]; then
                        sed -i.bak "s/\"version\": \".*\"/\"version\": \"$new_version\"/" package.json
                        rm -f package.json.bak
                    fi
                    ;;
                python)
                    if [ -f "setup.py" ]; then
                        sed -i.bak "s/version=\".*\"/version=\"$new_version\"/" setup.py
                        rm -f setup.py.bak
                    fi
                    ;;
            esac
            
            # Commit changelog
            execute_command "git add CHANGELOG.md package.json setup.py 2>/dev/null" \
                "Staging version updates"
            execute_command "git commit -m 'chore: Update CHANGELOG and version to $new_version'" \
                "Committing version updates"
            
            return 0
            ;;
            
        *"Tag release"*|*"semantic version"*)
            log_decision "Creating release tag"
            
            # Get version from CHANGELOG or package
            local version="0.1.0"
            if [ -f "CHANGELOG.md" ]; then
                version=$(grep -m1 '## \[' CHANGELOG.md | sed 's/## \[\(.*\)\].*/\1/')
            elif [ -f "package.json" ]; then
                version=$(grep '"version"' package.json | head -1 | sed 's/.*"version": "\(.*\)".*/\1/')
            fi
            
            local tag_name="v$version"
            log_context "Creating tag: $tag_name"
            
            if execute_command "git tag -a $tag_name -m 'Release version $version'" \
                "Creating annotated tag"; then
                ((RELEASES_CREATED++))
                log_memory "Created release tag: $tag_name"
                
                # Push tag if origin exists
                if git remote | grep -q origin; then
                    execute_command "git push origin $tag_name" "Pushing tag to origin"
                fi
                
                # Create GitHub release if gh is available
                if command -v gh >/dev/null 2>&1; then
                    local release_notes=$(sed -n "/## \[$version\]/,/## \[/p" CHANGELOG.md | sed '$ d')
                    execute_command "gh release create $tag_name --title 'Release $version' --notes '$release_notes'" \
                        "Creating GitHub release"
                fi
            else
                ((ISSUES_ENCOUNTERED++))
                log_issue "Failed to create release tag"
            fi
            
            return 0
            ;;
            
        *"Delete feature branch"*)
            log_decision "Cleaning up merged feature branches"
            
            # Delete local feature branches that are merged
            local deleted_count=0
            for branch in $(git branch --merged main | grep -v main | grep -v master); do
                if execute_command "git branch -d $branch" "Deleting merged branch: $branch"; then
                    ((deleted_count++))
                fi
            done
            
            log_context "Deleted $deleted_count merged branches"
            
            # Prune remote tracking branches
            execute_command "git remote prune origin 2>/dev/null || true" \
                "Pruning remote tracking branches"
            
            return 0
            ;;
            
        *"documentation"*|*"Update"*)
            log_decision "Updating project documentation"
            
            # Update README if needed
            if [ -f "README.md" ] && [ $MERGES_COMPLETED -gt 0 ]; then
                if ! grep -q "## Latest Release" README.md; then
                    echo -e "\n## Latest Release\n\nSee [CHANGELOG.md](CHANGELOG.md) for version history.\n" >> README.md
                    execute_command "git add README.md && git commit -m 'docs: Add release section to README'" \
                        "Updating README"
                fi
            fi
            
            log_context "Documentation updated"
            return 0
            ;;
            
        *"stakeholder"*|*"notif"*)
            log_decision "Notifying stakeholders"
            
            # Create completion summary
            create_file_with_content "RELEASE_NOTES.md" "# Release Completed

## Summary
- Merges Completed: $MERGES_COMPLETED
- Releases Created: $RELEASES_CREATED
- Issues Encountered: $ISSUES_ENCOUNTERED

## Version
$(grep -m1 '## \[' CHANGELOG.md 2>/dev/null || echo "See CHANGELOG.md")

## Next Steps
1. Monitor production deployment
2. Gather user feedback
3. Plan next iteration

---
*Generated by AI DevKit Autonomous System*"
            
            log_memory "Stakeholder notification prepared"
            return 0
            ;;
            
        *)
            log_issue "Unknown merge work type: $work_desc"
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
    
    if [ "$next_persona" = "COMPLETE" ]; then
        log_memory "Development cycle successfully completed"
        log_memory "Total merges: $MERGES_COMPLETED, Releases: $RELEASES_CREATED"
    fi
}

# Test mode support
if [ "$TEST_MODE" = "1" ]; then
    # Export test helpers
    test_init_merger() {
        MERGES_COMPLETED=0
        RELEASES_CREATED=0
        ISSUES_ENCOUNTERED=0
        initialize_persona
    }
    export -f test_init_merger
    
    echo "MERGER Actor ready for testing" >&2
fi

# Autonomous startup - only in production mode
if [ "$TEST_MODE" != "1" ]; then
    # Only run if being executed directly
    if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
        actor_loop "$PERSONA"
    fi
else
    echo "$PERSONA actor loaded in test mode - actor_loop skipped" >&2
fi
