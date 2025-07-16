#!/bin/bash
# CQRS projection system - builds read models from event stream
# Usage: es-projection PERSONA PROJECTION_TYPE [OPTIONS]

PERSONA="$1"
PROJECTION="$2"
JOURNAL_FILE="${JOURNAL_FILE:-$HOME/workspace/JOURNAL.md}"

# Ensure journal exists
if [ ! -f "$JOURNAL_FILE" ]; then
    echo "# Development Journal" > "$JOURNAL_FILE"
    echo "" >> "$JOURNAL_FILE"
fi

case "$PROJECTION" in
    pending_work)
        # Find all work assigned to persona that hasn't been completed
        grep "TYPE:WORK_ASSIGNED.*TO:$PERSONA" "$JOURNAL_FILE" | while IFS= read -r line; do
            if [[ "$line" =~ ID:([^|]+) ]]; then
                work_id="${BASH_REMATCH[1]}"
                # Check if this work has been completed or failed
                if ! grep -q "TYPE:WORK_COMPLETED.*WORK_ID:$work_id\|TYPE:WORK_FAILED.*WORK_ID:$work_id" "$JOURNAL_FILE"; then
                    echo "$line"
                fi
            fi
        done
        ;;
        
    current_state)
        # Determine current state of a persona
        # States: ACTIVE, IDLE, COMPLETE, UNKNOWN
        last_event=$(grep "PERSONA:$PERSONA" "$JOURNAL_FILE" | tail -1)
        
        if [ -z "$last_event" ]; then
            echo "UNKNOWN"
        elif [[ "$last_event" =~ TYPE:PERSONA_ACTIVATED ]]; then
            # Check if still has work
            pending=$(es-projection "$PERSONA" "pending_work" | wc -l)
            if [ "$pending" -gt 0 ]; then
                echo "ACTIVE"
            else
                echo "IDLE"
            fi
        elif [[ "$last_event" =~ TYPE:PERSONA_IDLE ]]; then
            echo "IDLE"
        elif [[ "$last_event" =~ TYPE:HANDOFF_READY.*FROM:$PERSONA ]]; then
            echo "COMPLETE"
        else
            echo "UNKNOWN"
        fi
        ;;
        
    work_history)
        # Get history of work items for a persona
        work_id="${3:-}"
        if [ -n "$work_id" ]; then
            # Specific work item history
            grep -E "WORK_ID:$work_id|ID:$work_id" "$JOURNAL_FILE"
        else
            # All work history for persona
            grep -E "PERSONA:$PERSONA.*(WORK_|TYPE:WORK_)" "$JOURNAL_FILE"
        fi
        ;;
        
    decisions)
        # Get all decisions made by persona
        grep "\[$PERSONA:DECISION\]" "$JOURNAL_FILE"
        ;;
        
    issues)
        # Get all issues logged by persona
        grep "\[$PERSONA:ISSUE\]" "$JOURNAL_FILE"
        ;;
        
    handoffs)
        # Get handoff history involving this persona
        grep -E "FROM:$PERSONA|TO:$PERSONA" "$JOURNAL_FILE" | grep "HANDOFF"
        ;;
        
    active_personas)
        # Find all currently active personas
        for p in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
            state=$(es-projection "$p" "current_state")
            if [ "$state" = "ACTIVE" ]; then
                echo "$p"
            fi
        done
        ;;
        
    stats)
        # Get statistics for a persona
        total_assigned=$(grep "TYPE:WORK_ASSIGNED.*TO:$PERSONA" "$JOURNAL_FILE" | wc -l)
        total_completed=$(grep "TYPE:WORK_COMPLETED.*PERSONA:$PERSONA" "$JOURNAL_FILE" | wc -l)
        total_failed=$(grep "TYPE:WORK_FAILED.*PERSONA:$PERSONA" "$JOURNAL_FILE" | wc -l)
        pending=$(es-projection "$PERSONA" "pending_work" | wc -l)
        
        echo "=== $PERSONA Statistics ==="
        echo "Total Assigned: $total_assigned"
        echo "Completed: $total_completed"
        echo "Failed: $total_failed"
        echo "Pending: $pending"
        echo "Success Rate: $(( total_completed * 100 / (total_completed + total_failed + 1) ))%"
        ;;
        
    next_work)
        # Get the next work item for persona (oldest pending)
        es-projection "$PERSONA" "pending_work" | head -1
        ;;
        
    work_description)
        # Extract work description from a work assigned event
        work_id="${3:-}"
        if [ -n "$work_id" ]; then
            grep "TYPE:WORK_ASSIGNED.*ID:$work_id" "$JOURNAL_FILE" | head -1 | sed 's/.*WORK://'
        fi
        ;;
        
    last_handoff_to)
        # Find who last handed off to this persona
        grep "TYPE:HANDOFF_READY.*TO:$PERSONA" "$JOURNAL_FILE" | tail -1 | grep -o "FROM:[^|]*" | cut -d: -f2
        ;;
        
    system_state)
        # Overall system state
        echo "=== System State ==="
        echo "Active Personas: $(es-projection "" "active_personas" | tr '\n' ' ')"
        echo ""
        for p in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
            state=$(es-projection "$p" "current_state")
            pending=$(es-projection "$p" "pending_work" | wc -l)
            echo "$p: $state (pending: $pending)"
        done
        ;;
        
    *)
        echo "Usage: es-projection PERSONA PROJECTION_TYPE [OPTIONS]"
        echo ""
        echo "Projection types:"
        echo "  pending_work     - List pending work items"
        echo "  current_state    - Get current state (ACTIVE/IDLE/COMPLETE)"
        echo "  work_history     - Show work history"
        echo "  decisions        - List decisions made"
        echo "  issues           - List issues encountered"
        echo "  handoffs         - Show handoff history"
        echo "  active_personas  - List all active personas"
        echo "  stats            - Show statistics"
        echo "  next_work        - Get next work item"
        echo "  work_description - Get work description by ID"
        echo "  last_handoff_to  - Who handed off to this persona"
        echo "  system_state     - Overall system state"
        exit 1
        ;;
esac
