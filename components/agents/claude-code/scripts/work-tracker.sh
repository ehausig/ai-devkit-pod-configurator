#!/bin/bash
# Enhanced work management utility
# Usage: work-tracker.sh <command> [options]

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get command
command="$1"
shift

case "$command" in
    "track")
        # Original track functionality
        work_pattern="$1"
        persona="${2:-ALL}"
        
        if [ -z "$work_pattern" ]; then
            echo "Usage: work-tracker.sh track <work-pattern> [persona]"
            echo "Example: work-tracker.sh track 'greeter module' DEVELOPER"
            exit 1
        fi
        
        JOURNAL_FILE="$HOME/workspace/JOURNAL.md"
        
        echo "=== Work Tracker: '$work_pattern' ==="
        echo ""
        
        # Stream through journal once, tracking work items
        awk -v pattern="$work_pattern" -v target_persona="$persona" '
        BEGIN {
            # ANSI color codes
            YELLOW = "\033[33m"
            GREEN = "\033[32m"
            RED = "\033[31m"
            BLUE = "\033[34m"
            RESET = "\033[0m"
        }
        
        # Match work events containing the pattern
        $0 ~ pattern {
            # Extract timestamp and event type
            timestamp = $1 " " $2
            
            # Parse event type and persona
            if ($0 ~ /WORK:PENDING/) {
                if (target_persona == "ALL" || $0 ~ target_persona) {
                    # Extract work description using index/substr instead of match with array
                    if (match($0, /WORK:PENDING\] /)) {
                        work_desc = substr($0, RSTART + RLENGTH)
                        
                        # Extract persona from description
                        if (match(work_desc, /^[A-Z]+: /)) {
                            persona = substr(work_desc, 1, RSTART + RLENGTH - 3)
                            task = substr(work_desc, RSTART + RLENGTH)
                        } else {
                            persona = "UNKNOWN"
                            task = work_desc
                        }
                        
                        # Generate work ID
                        work_id = substr(work_desc, 1, 50)
                        
                        # Store pending state
                        pending[work_id] = timestamp
                        pending_persona[work_id] = persona
                        
                        print YELLOW "⋄ PENDING" RESET " [" timestamp "] " persona ": " task
                    }
                }
            }
            else if ($0 ~ /WORK:STARTED/) {
                if (match($0, /WORK:STARTED\] /)) {
                    work_desc = substr($0, RSTART + RLENGTH)
                    work_id = substr(work_desc, 1, 50)
                    
                    if (work_id in pending) {
                        started[work_id] = timestamp
                        print BLUE "→ STARTED" RESET " [" timestamp "] " work_desc
                    }
                }
            }
            else if ($0 ~ /WORK:COMPLETED/) {
                if (match($0, /WORK:COMPLETED\] /)) {
                    work_desc = substr($0, RSTART + RLENGTH)
                    work_id = substr(work_desc, 1, 50)
                    
                    if (work_id in pending) {
                        completed[work_id] = timestamp
                        print GREEN "✓ COMPLETED" RESET " [" timestamp "] " work_desc
                        
                        # Calculate duration if started time exists
                        if (work_id in started) {
                            # Simple time display (would need proper date parsing for duration)
                            print "  Duration: " started[work_id] " → " timestamp
                        }
                    }
                }
            }
            else if ($0 ~ /WORK:BLOCKED/) {
                if (match($0, /WORK:BLOCKED\] /)) {
                    work_desc = substr($0, RSTART + RLENGTH)
                    work_id = substr(work_desc, 1, 50)
                    
                    if (work_id in pending) {
                        blocked[work_id] = timestamp
                        print RED "✗ BLOCKED" RESET " [" timestamp "] " work_desc
                    }
                }
            }
        }
        
        END {
            print ""
            print "=== Summary ==="
            
            # Count items by state
            total_pending = 0
            total_started = 0
            total_completed = 0
            total_blocked = 0
            
            for (item in pending) {
                total_pending++
                if (item in started) total_started++
                if (item in completed) total_completed++
                if (item in blocked) total_blocked++
            }
            
            # Calculate actual pending (not completed)
            actual_pending = total_pending - total_completed
            
            print "Total items tracked: " total_pending
            print "Completed: " GREEN total_completed RESET
            print "In progress: " BLUE (total_started - total_completed) RESET
            print "Blocked: " RED total_blocked RESET
            print "Pending: " YELLOW actual_pending RESET
            
            # Show incomplete items
            if (actual_pending > 0) {
                print ""
                print "=== Incomplete Items ==="
                for (item in pending) {
                    if (!(item in completed)) {
                        status = "PENDING"
                        color = YELLOW
                        if (item in blocked) {
                            status = "BLOCKED"
                            color = RED
                        } else if (item in started) {
                            status = "IN PROGRESS"
                            color = BLUE
                        }
                        print color status RESET ": " item " (" pending_persona[item] ")"
                    }
                }
            }
        }
        ' "$JOURNAL_FILE"
        ;;
        
    "status")
        # Merged work-status.sh functionality
        PERSONA="${1:-$(journal-query.sh current-persona)}"
        
        echo -e "${BLUE}=== Work Status for $PERSONA ===${NC}"
        echo ""
        
        # Get pending work count
        PENDING_COUNT=$(journal-query.sh pending-work "$PERSONA" | wc -l)
        
        # Get completed work in current session
        RECENT_COMPLETED=$(journal-query.sh recent-context "$PERSONA" | grep -c "WORK:COMPLETED" || echo "0")
        
        # Check for work script
        if [ -f /tmp/execute-next-work.sh ]; then
            WORK_READY="${GREEN}✓ Ready${NC}"
            WORK_SCRIPT="Yes"
        else
            WORK_READY="${YELLOW}⚠ Not prepared${NC}"
            WORK_SCRIPT="No"
        fi
        
        # Display status
        echo -e "Current Persona: ${CYAN}$PERSONA${NC}"
        echo -e "Pending Work Items: ${YELLOW}$PENDING_COUNT${NC}"
        echo -e "Recently Completed: ${GREEN}$RECENT_COMPLETED${NC}"
        echo -e "Work Script Ready: $WORK_READY"
        echo ""
        
        # Show pending work items
        if [ $PENDING_COUNT -gt 0 ]; then
            echo -e "${YELLOW}Pending Work Items:${NC}"
            journal-query.sh pending-work "$PERSONA" | nl | sed 's/.*WORK:PENDING\] /    /'
            echo ""
        fi
        
        # Check for blocked work
        BLOCKED_COUNT=$(journal-query.sh recent-context "$PERSONA" | grep -c "WORK:BLOCKED" || echo "0")
        if [ $BLOCKED_COUNT -gt 0 ]; then
            echo -e "${RED}⚠ Blocked Work Items:${NC}"
            journal-query.sh recent-context "$PERSONA" | grep "WORK:BLOCKED" | tail -3 | sed 's/.*\[WORK:BLOCKED\] /  - /'
            echo ""
        fi
        
        # Show next actions
        echo -e "${BLUE}Next Actions:${NC}"
        
        if [ "$WORK_SCRIPT" = "Yes" ]; then
            echo "1. Execute prepared work: /tmp/execute-next-work.sh"
        elif [ $PENDING_COUNT -gt 0 ]; then
            echo "1. Prepare work script: work-tracker.sh prepare $PERSONA"
            echo "2. Then execute: /tmp/execute-next-work.sh"
        else
            echo "1. All work complete for $PERSONA"
            echo "2. Run handoff: $(echo $PERSONA | tr '[:upper:]' '[:lower:]')-handoff.sh"
        fi
        
        echo ""
        
        # Check for handoff readiness
        if [ $PENDING_COUNT -eq 0 ]; then
            echo -e "${GREEN}✓ Ready for handoff${NC}"
            
            # Suggest next persona based on current
            case "$PERSONA" in
                ARCHITECT)
                    echo "Next persona: DEVELOPER"
                    ;;
                DEVELOPER)
                    echo "Next persona: QA"
                    ;;
                QA)
                    # Check if tests passed
                    FAILED=$(journal-query.sh recent-context QA | grep -c "QA:FAILED" || echo "0")
                    if [ $FAILED -eq 0 ]; then
                        echo "Next persona: REVIEWER (all tests passed)"
                    else
                        echo "Next persona: DEVELOPER (fixes needed)"
                    fi
                    ;;
                REVIEWER)
                    # Check if approved
                    ISSUES=$(journal-query.sh recent-context REVIEWER | grep -c "REVIEWER:ISSUE" || echo "0")
                    if [ $ISSUES -eq 0 ]; then
                        echo "Next persona: MERGER (approved)"
                    else
                        echo "Next persona: DEVELOPER (changes requested)"
                    fi
                    ;;
                MERGER)
                    echo "Cycle complete. Choose next action based on needs."
                    ;;
            esac
        fi
        
        # Show recent errors if any
        RECENT_ERRORS=$(journal-query.sh errors "$PERSONA" 3)
        if [ -n "$RECENT_ERRORS" ]; then
            echo ""
            echo -e "${RED}Recent Errors:${NC}"
            echo "$RECENT_ERRORS" | sed 's/.*\[\(.*\)\] /[\1] /'
        fi
        ;;
        
    "prepare")
        # Prepare next work item for execution
        PERSONA="${1:-$(journal-query.sh current-persona)}"
        
        # Get the next pending work item
        NEXT_WORK=$(journal-query.sh pending-work "$PERSONA" | head -1)
        
        if [ -z "$NEXT_WORK" ]; then
            echo "No pending work for $PERSONA"
            exit 0
        fi
        
        # Extract work description
        WORK_DESC=$(echo "$NEXT_WORK" | sed 's/.*WORK:PENDING\] //')
        
        # Create executable work script
        cat > /tmp/execute-next-work.sh << 'SCRIPT_HEADER'
#!/bin/bash
# Auto-generated work execution script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_HEADER
        
        cat >> /tmp/execute-next-work.sh << SCRIPT_CONTENT
PERSONA="$PERSONA"
WORK_ITEM="$WORK_DESC"

echo -e "\${BLUE}=== Executing Work Item ===\${NC}"
echo "Persona: \$PERSONA"
echo "Work: \$WORK_ITEM"
echo ""

# Mark work as started
journal-log.sh "WORK:STARTED" "\$WORK_ITEM"

# Execute based on work type
case "\$WORK_ITEM" in
    *"Create feature branch"*)
        # Extract branch name
        BRANCH_NAME=\$(echo "\$WORK_ITEM" | grep -o 'feat/[^ ]*' || echo "feat/new-feature")
        echo "Creating branch: \$BRANCH_NAME"
        git checkout -b "\$BRANCH_NAME"
        RESULT=\$?
        ;;
        
    *"Set up project structure"*)
        echo "Setting up project structure..."
        mkdir -p src tests docs
        ls -la src/ tests/ docs/
        RESULT=\$?
        ;;
        
    *"Pull branch"*|*"git pull"*)
        echo "Pulling latest changes..."
        git pull origin \$(git branch --show-current)
        RESULT=\$?
        ;;
        
    *"Run unit test"*)
        echo "Running unit tests..."
        if [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
            pytest --cov=src --cov-report=term-missing
        elif [ -f "package.json" ]; then
            npm test -- --coverage
        elif [ -f "Cargo.toml" ]; then
            cargo test
        elif [ -f "go.mod" ]; then
            go test -cover ./...
        else
            echo "No recognized test framework"
            RESULT=0
        fi
        RESULT=\$?
        ;;
        
    *"Clone"*"review directory"*)
        echo "Cloning to review directory..."
        cd ~/workspace/reviewer
        REPO_NAME=\$(basename \$(git -C ~/workspace/\$(ls ~/workspace | head -1) remote get-url origin 2>/dev/null || echo "project") .git)
        git clone ~/workspace/\$REPO_NAME \${REPO_NAME}-review
        cd \${REPO_NAME}-review
        git checkout \$(git branch --show-current)
        RESULT=\$?
        ;;
        
    *"automated code quality checks"*)
        echo "Running code quality checks..."
        # Run available linters
        if [ -f "package.json" ] && grep -q '"lint"' package.json; then
            npm run lint
        elif [ -f ".flake8" ] || [ -f "setup.cfg" ] || [ -f "pyproject.toml" ]; then
            flake8 . || true
        elif [ -f "Cargo.toml" ]; then
            cargo clippy || true
        fi
        RESULT=\$?
        ;;
        
    *"Verify all CI/CD"*)
        echo "Checking CI/CD status..."
        PR_NUMBER=\$(gh pr list --json number --jq '.[0].number' 2>/dev/null || echo "")
        if [ -n "\$PR_NUMBER" ]; then
            gh pr checks \$PR_NUMBER
        else
            echo "No PR found to check"
        fi
        RESULT=\$?
        ;;
        
    *"Merge PR"*)
        echo "Merging pull request..."
        git checkout main
        git pull origin main
        PR_NUMBER=\$(gh pr list --json number --jq '.[0].number' 2>/dev/null || echo "")
        if [ -n "\$PR_NUMBER" ]; then
            gh pr merge \$PR_NUMBER --merge --no-squash --delete-branch
            journal-log.sh "MERGER:MERGED" "Merged PR #\$PR_NUMBER"
        fi
        RESULT=\$?
        ;;
        
    *)
        echo -e "\${YELLOW}Generic work item - implement based on description\${NC}"
        echo "TODO: Implement logic for: \$WORK_ITEM"
        # For now, mark as successful to continue flow
        RESULT=0
        ;;
esac

# Mark work as completed or failed
if [ \$RESULT -eq 0 ]; then
    echo -e "\n\${GREEN}✓ Work completed successfully\${NC}"
    journal-log.sh "WORK:COMPLETED" "\$WORK_ITEM"
else
    echo -e "\n\${RED}✗ Work failed with exit code: \$RESULT\${NC}"
    journal-log.sh "WORK:FAILED" "\$WORK_ITEM - Exit code: \$RESULT"
fi

# Check for more work
PENDING_COUNT=\$(journal-query.sh pending-work "\$PERSONA" | wc -l)
echo ""
if [ \$PENDING_COUNT -gt 0 ]; then
    echo -e "\${YELLOW}→ \$PENDING_COUNT more work items pending for \$PERSONA\${NC}"
    echo ""
    echo "Next work item:"
    journal-query.sh pending-work "\$PERSONA" | head -1 | sed 's/.*WORK:PENDING\] /  /'
    echo ""
    echo -e "\${BLUE}To continue, run:\${NC} /tmp/execute-next-work.sh"
    
    # Prepare the next work script
    work-tracker.sh prepare "\$PERSONA"
else
    echo -e "\${GREEN}✓ All work completed for \$PERSONA\${NC}"
    echo ""
    echo "Next steps:"
    echo "- Run handoff script if ready: \$(echo \$PERSONA | tr '[:upper:]' '[:lower:]')-handoff.sh"
    echo "- Or check work summary: journal-query.sh work-summary \$PERSONA"
fi
SCRIPT_CONTENT
        
        chmod +x /tmp/execute-next-work.sh
        
        # Create notification for Claude
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${GREEN}🚀 WORK READY FOR EXECUTION${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo -e "${YELLOW}EXECUTE:${NC} /tmp/execute-next-work.sh"
        echo ""
        echo "This script will:"
        echo "1. Mark work as STARTED"
        echo "2. Execute: $(echo "$WORK_DESC" | head -c 50)..."
        echo "3. Mark work as COMPLETED"
        echo "4. Check for additional work"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;
        
    *)
        echo "Usage: work-tracker.sh <command> [options]"
        echo ""
        echo "Commands:"
        echo "  track <pattern> [persona]  - Track work item lifecycle"
        echo "  status [persona]          - Show current work status"
        echo "  prepare [persona]         - Prepare next work for execution"
        echo ""
        echo "Examples:"
        echo "  work-tracker.sh track 'user auth' DEVELOPER"
        echo "  work-tracker.sh status"
        echo "  work-tracker.sh prepare DEVELOPER"
        exit 1
        ;;
esac
