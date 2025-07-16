#!/bin/bash
# Cleanup script for obsolete files from the refactoring
# This removes all legacy persona scripts and hook implementations

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}Event-Driven Refactor Cleanup Script${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""
echo "This script will remove obsolete files from the old procedural architecture."
echo ""

# Dry run by default
DRY_RUN=true
if [ "$1" = "--execute" ]; then
    DRY_RUN=false
    echo -e "${RED}EXECUTING CLEANUP - Files will be permanently deleted!${NC}"
else
    echo -e "${GREEN}DRY RUN MODE - No files will be deleted${NC}"
    echo "Run with --execute to actually delete files"
fi
echo ""

# Function to remove file/directory
remove_item() {
    local item="$1"
    local type="$2"  # "file" or "directory"
    
    if [ -e "$item" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}[DRY RUN]${NC} Would remove $type: $item"
        else
            if [ "$type" = "directory" ]; then
                rm -rf "$item"
            else
                rm -f "$item"
            fi
            echo -e "${RED}[REMOVED]${NC} $type: $item"
        fi
    fi
}

echo "Removing obsolete persona initialization scripts..."
remove_item "components/agents/claude-code/scripts/personas/persona-architect-init.sh" "file"
remove_item "components/agents/claude-code/scripts/personas/persona-developer-init.sh" "file"
remove_item "components/agents/claude-code/scripts/personas/persona-qa-init.sh" "file"
remove_item "components/agents/claude-code/scripts/personas/persona-reviewer-init.sh" "file"
remove_item "components/agents/claude-code/scripts/personas/persona-merger-init.sh" "file"

echo ""
echo "Removing obsolete persona handoff scripts..."
remove_item "components/agents/claude-code/scripts/personas/persona-architect-handoff.sh" "file"
remove_item "components/agents/claude-code/scripts/personas/persona-developer-handoff.sh" "file"
remove_item "components/agents/claude-code/scripts/personas/persona-qa-handoff.sh" "file"
remove_item "components/agents/claude-code/scripts/personas/persona-reviewer-handoff.sh" "file"
remove_item "components/agents/claude-code/scripts/personas/persona-merger-handoff.sh" "file"

echo ""
echo "Removing obsolete hook implementations..."
remove_item "components/agents/claude-code/hooks/logic/cc-hook-logic-work-queue-monitor.sh" "file"
remove_item "components/agents/claude-code/hooks/scripts/cc-hook-work-queue-monitor.sh" "file"
remove_item "components/agents/claude-code/hooks/scripts/cc-hook-journal.sh" "file"
remove_item "components/agents/claude-code/hooks/logic/cc-hook-logic-journal.sh" "file"

echo ""
echo "Removing obsolete autonomous controller..."
remove_item "components/agents/claude-code/scripts/common/setup-autonomous-mode.sh" "file"

echo ""
echo "Removing legacy event sourcing scripts..."
remove_item "components/agents/claude-code/scripts/event-sourcing/es-journal-log.sh" "file"
remove_item "components/agents/claude-code/scripts/event-sourcing/es-journal-query.sh" "file"
remove_item "components/agents/claude-code/scripts/event-sourcing/es-context-window.sh" "file"
remove_item "components/agents/claude-code/scripts/event-sourcing/es-work-tracker.sh" "file"

echo ""
echo "Removing obsolete commands..."
remove_item "components/agents/claude-code/commands/execute-work.md" "file"
remove_item "components/agents/claude-code/commands/journal-summary.md" "file"
remove_item "components/agents/claude-code/commands/list-handoffs.md" "file"
remove_item "components/agents/claude-code/commands/show-context.md" "file"
remove_item "components/agents/claude-code/commands/switch-persona.md" "file"
remove_item "components/agents/claude-code/commands/work-status.md" "file"

echo ""
echo "Removing process-hooks.py..."
remove_item "components/agents/claude-code/process-hooks.py" "file"

echo ""
echo -e "${GREEN}Cleanup complete!${NC}"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "This was a dry run. To actually delete files, run:"
    echo "  $0 --execute"
fi

# Count remaining files
echo ""
echo "Remaining files in refactored system:"
echo "  Event sourcing scripts: $(ls components/agents/claude-code/scripts/event-sourcing/*.sh 2>/dev/null | wc -l)"
echo "  Persona actors: $(ls components/agents/claude-code/scripts/personas/*-actor.sh 2>/dev/null | wc -l)"
echo "  Hook scripts: $(ls components/agents/claude-code/hooks/scripts/*.sh 2>/dev/null | wc -l)"
echo "  Commands: $(ls components/agents/claude-code/commands/*.md 2>/dev/null | wc -l)"
