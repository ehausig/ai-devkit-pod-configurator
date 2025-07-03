#!/bin/bash
# Core journal query script - provides ephemeral views of journal data
# Usage: journal-query <query-type> [persona] [limit] [options]

# Get parameters
query_type=$1
persona=${2:-$(grep "PERSONA:INIT" ~/workspace/JOURNAL.md 2>/dev/null | tail -1 | grep -o '\[.*:' | tr -d '[:[]' || echo "UNKNOWN")}
limit=${3:-20}

# Ensure journal exists
JOURNAL_FILE="$HOME/workspace/JOURNAL.md"
if [ ! -f "$JOURNAL_FILE" ]; then
    echo "No journal file found at $JOURNAL_FILE"
    exit 1
fi

case "$query_type" in
    "pending-work")
        # Get pending work for persona
        grep "WORK:PENDING.*${persona}:" "$JOURNAL_FILE" 2>/dev/null | \
            while read -r line; do
                # Extract work description after the tag
                work_desc=$(echo "$line" | sed 's/.*WORK:PENDING\] //')
                # Generate a short hash for the work item
                work_hash=$(echo "$work_desc" | md5sum | cut -c1-8)
                
                # Check if this exact work was completed
                if ! grep -q "WORK:COMPLETED.*$work_desc" "$JOURNAL_FILE" 2>/dev/null; then
                    echo "$line"
                fi
            done | tail -$limit
        ;;
        
    "recent-context")
        # Get recent events for current persona
        grep "\[${persona}:" "$JOURNAL_FILE" 2>/dev/null | tail -$limit
        ;;
        
    "handoff-ready")
        # Check if ready for handoff
        pending=$(journal-query pending-work "$persona" | wc -l)
        if [ $pending -eq 0 ]; then
            echo "Ready for handoff - no pending work"
            exit 0
        else
            echo "Not ready - $pending items pending:"
            journal-query pending-work "$persona" | sed 's/.*WORK:PENDING\] /  - /'
            exit 1
        fi
        ;;
        
    "safety-check")
        # Check iteration count and recent progress
        init_count=$(grep -c "\[${persona}:INIT\]" "$JOURNAL_FILE" 2>/dev/null || echo "0")
        recent_progress=$(tail -100 "$JOURNAL_FILE" 2>/dev/null | grep -c "WORK:COMPLETED.*${persona}" || echo "0")
        echo "Iterations: $init_count, Recent completions: $recent_progress"
        
        # Check for safety limits
        if [ $init_count -gt 10 ]; then
            echo "WARNING: High iteration count ($init_count)"
            exit 1
        fi
        
        if [ $init_count -gt 3 ] && [ $recent_progress -eq 0 ]; then
            echo "WARNING: No recent progress detected"
            exit 2
        fi
        ;;
        
    "decisions")
        # Get architectural decisions
        grep ":DECISION\]" "$JOURNAL_FILE" 2>/dev/null | tail -$limit
        ;;
        
    "memory")
        # Get persistent memories
        grep ":MEMORY\]" "$JOURNAL_FILE" 2>/dev/null | tail -$limit
        ;;
        
    "errors")
        # Get recent errors/blocks
        grep -E "(ERROR|BLOCKED|FAILED)" "$JOURNAL_FILE" 2>/dev/null | tail -$limit
        ;;
        
    "work-history")
        # Show work progression for an item
        work_pattern="$4"
        if [ -z "$work_pattern" ]; then
            echo "Usage: journal-query work-history <persona> <limit> <work-pattern>"
            exit 1
        fi
        grep -E "(PENDING|STARTED|COMPLETED|BLOCKED).*$work_pattern" "$JOURNAL_FILE" 2>/dev/null
        ;;
        
    "handoff-chain")
        # Show handoff history
        grep "HANDOFF:COMPLETED" "$JOURNAL_FILE" 2>/dev/null | tail -$limit
        ;;
        
    "current-persona")
        # Get the current active persona
        grep "PERSONA:INIT" "$JOURNAL_FILE" 2>/dev/null | tail -1 | \
            sed 's/.*\[\(.*\):INIT\].*/\1/'
        ;;
        
    "work-summary")
        # Summary of work items by state
        echo "=== Work Summary for $persona ==="
        echo "Pending: $(grep -c "WORK:PENDING.*${persona}:" "$JOURNAL_FILE" 2>/dev/null || echo "0")"
        echo "Started: $(grep -c "WORK:STARTED.*${persona}:" "$JOURNAL_FILE" 2>/dev/null || echo "0")"
        echo "Completed: $(grep -c "WORK:COMPLETED.*${persona}:" "$JOURNAL_FILE" 2>/dev/null || echo "0")"
        echo "Blocked: $(grep -c "WORK:BLOCKED.*${persona}:" "$JOURNAL_FILE" 2>/dev/null || echo "0")"
        ;;
        
    *)
        echo "Usage: journal-query <query-type> [persona] [limit] [options]"
        echo ""
        echo "Query types:"
        echo "  pending-work     - Show pending work items"
        echo "  recent-context   - Show recent persona events"
        echo "  handoff-ready    - Check if ready for handoff"
        echo "  safety-check     - Check iteration limits"
        echo "  decisions        - Show architectural decisions"
        echo "  memory           - Show persistent memories"
        echo "  errors           - Show recent errors/blocks"
        echo "  work-history     - Show history for specific work"
        echo "  handoff-chain    - Show handoff history"
        echo "  current-persona  - Get current active persona"
        echo "  work-summary     - Summary of work states"
        exit 1
        ;;
esac
