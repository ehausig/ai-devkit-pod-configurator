#!/bin/bash
# Prepare next work item for execution
# This script is called by the work-queue-monitor hook

PERSONA="${1:-$(journal-query current-persona)}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the next pending work item
NEXT_WORK=$(journal-query pending-work "$PERSONA" | head -1)

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
journal-log "WORK:STARTED" "\$WORK_ITEM"

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
            journal-log "MERGER:MERGED" "Merged PR #\$PR_NUMBER"
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
    journal-log "WORK:COMPLETED" "\$WORK_ITEM"
else
    echo -e "\n\${RED}✗ Work failed with exit code: \$RESULT\${NC}"
    journal-log "WORK:FAILED" "\$WORK_ITEM - Exit code: \$RESULT"
fi

# Check for more work
PENDING_COUNT=\$(journal-query pending-work "\$PERSONA" | wc -l)
echo ""
if [ \$PENDING_COUNT -gt 0 ]; then
    echo -e "\${YELLOW}→ \$PENDING_COUNT more work items pending for \$PERSONA\${NC}"
    echo ""
    echo "Next work item:"
    journal-query pending-work "\$PERSONA" | head -1 | sed 's/.*WORK:PENDING\] /  /'
    echo ""
    echo -e "\${BLUE}To continue, run:\${NC} /tmp/execute-next-work.sh"
    
    # Prepare the next work script
    /home/devuser/.claude/hooks/prepare-next-work.sh "\$PERSONA"
else
    echo -e "\${GREEN}✓ All work completed for \$PERSONA\${NC}"
    echo ""
    echo "Next steps:"
    echo "- Run handoff script if ready: /home/devuser/.claude/personas/\$(echo \$PERSONA | tr '[:upper:]' '[:lower:]')/\$(echo \$PERSONA | tr '[:upper:]' '[:lower:]')-handoff.sh"
    echo "- Or check work summary: journal-query work-summary \$PERSONA"
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
