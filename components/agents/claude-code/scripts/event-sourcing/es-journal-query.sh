#!/bin/bash
# Core journal query script - provides ephemeral views of journal data
# Usage: es-journal-query.sh <query-type> [persona] [limit] [options]

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
        # Use a more robust approach to track pending vs completed work
        
        # First, get all WORK:PENDING entries for this persona
        pending_items=$(grep "WORK:PENDING.*${persona}:" "$JOURNAL_FILE" 2>/dev/null)
        
        # For each pending item, check if it was completed
        echo "$pending_items" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                # Extract the work description (everything after WORK:PENDING] )
                work_desc=$(echo "$line" | sed 's/.*WORK:PENDING\] //')
                
                # Check if this exact work description appears in a WORK:COMPLETED entry
                # Use exact string matching to avoid partial matches
                if ! grep -F "WORK:COMPLETED] $work_desc" "$JOURNAL_FILE" >/dev/null 2>&1; then
                    echo "$line"
                fi
            fi
        done | tail -$limit
        ;;
        
    "recent-context")
        # Get recent events for current persona
        grep "\[${persona}:" "$JOURNAL_FILE" 2>/dev/null | tail -$limit
        ;;
        
    "handoff-ready")
        # Check if ready for handoff
        pending=$(es-journal-query.sh pending-work "$persona" | wc -l)
        if [ $pending -eq 0 ]; then
            echo "Ready for handoff - no pending work"
            exit 0
        else
            echo "Not ready - $pending items pending:"
            es-journal-query.sh pending-work "$persona" | sed 's/.*WORK:PENDING\] /  - /'
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
            echo "Usage: es-journal-query.sh work-history <persona> <limit> <work-pattern>"
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
        
    "work-completed-persona")
        # Extract persona from most recent WORK:COMPLETED entry
        # This handles various formats:
        # - "DEVELOPER: Task description"
        # - Direct persona extraction from work completion
        grep "WORK:COMPLETED" "$JOURNAL_FILE" 2>/dev/null | tail -1 | \
            sed 's/.*WORK:COMPLETED\] \([A-Z][A-Z]*\):.*/\1/' | \
            grep -E '^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$'
        ;;
        
    "should-handoff")
        # Determine if a persona should hand off and to whom
        # Usage: es-journal-query.sh should-handoff [persona]
        target_persona="${2:-$(es-journal-query.sh current-persona)}"
        pending=$(es-journal-query.sh pending-work "$target_persona" | wc -l)
        
        if [ "$pending" -eq 0 ]; then
            # No pending work, determine next persona based on current
            case "$target_persona" in
                ARCHITECT) echo "DEVELOPER" ;;
                DEVELOPER) 
                    # Check if going to QA or back from review
                    if grep -q "changes requested\|REVIEWER:ISSUE" "$JOURNAL_FILE" 2>/dev/null | tail -10; then
                        echo "QA"
                    else
                        echo "QA"
                    fi
                    ;;
                QA)
                    # Check if tests passed
                    failed=$(grep "QA:FAILED" "$JOURNAL_FILE" 2>/dev/null | tail -10 | wc -l)
                    if [ "$failed" -eq 0 ]; then
                        echo "REVIEWER"
                    else
                        echo "DEVELOPER"
                    fi
                    ;;
                REVIEWER)
                    # Check if approved
                    issues=$(grep "REVIEWER:ISSUE" "$JOURNAL_FILE" 2>/dev/null | tail -10 | wc -l)
                    if [ "$issues" -eq 0 ]; then
                        echo "MERGER"
                    else
                        echo "DEVELOPER"
                    fi
                    ;;
                MERGER) echo "ARCHITECT" ;; # Start new cycle
                *) echo "UNKNOWN" ;;
            esac
            exit 0
        else
            # Still has pending work, no handoff needed
            exit 1
        fi
        ;;
        
    "work-summary")
        # Summary of work items by state
        echo "=== Work Summary for $persona ==="
        echo "Pending: $(grep -c "WORK:PENDING.*${persona}:" "$JOURNAL_FILE" 2>/dev/null || echo "0")"
        echo "Started: $(grep -c "WORK:STARTED.*${persona}:" "$JOURNAL_FILE" 2>/dev/null || echo "0")"
        echo "Completed: $(grep -c "WORK:COMPLETED.*${persona}:" "$JOURNAL_FILE" 2>/dev/null || echo "0")"
        echo "Blocked: $(grep -c "WORK:BLOCKED.*${persona}:" "$JOURNAL_FILE" 2>/dev/null || echo "0")"
        ;;
        
    "stats")
        # Journal statistics (merged from journal-stats.sh)
        days_back=${4:-7}
        
        if [ "$days_back" = "all" ]; then
            cutoff_date="1970-01-01"
        else
            cutoff_date=$(date -d "$days_back days ago" +%Y-%m-%d 2>/dev/null || date -v-${days_back}d +%Y-%m-%d)
        fi
        
        echo "=== Journal Statistics (last $days_back days) ==="
        echo ""
        
        # Single pass through journal for efficiency
        awk -v cutoff="$cutoff_date" '
        BEGIN {
            # Initialize counters
            personas["ARCHITECT"] = 0
            personas["DEVELOPER"] = 0
            personas["QA"] = 0
            personas["REVIEWER"] = 0
            personas["MERGER"] = 0
            
            work_pending = 0
            work_started = 0
            work_completed = 0
            work_blocked = 0
            
            handoffs = 0
            decisions = 0
            memories = 0
            errors = 0
            
            total_events = 0
            first_date = ""
            last_date = ""
        }
        
        # Process each line
        {
            # Extract date
            date = substr($1, 1, 10)
            
            # Skip if before cutoff
            if (date < cutoff) next
            
            # Track date range
            if (first_date == "") first_date = $1
            last_date = $1
            
            total_events++
            
            # Count persona initializations
            if ($0 ~ /:INIT\]/) {
                for (p in personas) {
                    if ($0 ~ p ":INIT") {
                        personas[p]++
                        total_inits++
                    }
                }
            }
            
            # Count work states
            if ($0 ~ /WORK:PENDING/) work_pending++
            else if ($0 ~ /WORK:STARTED/) work_started++
            else if ($0 ~ /WORK:COMPLETED/) work_completed++
            else if ($0 ~ /WORK:BLOCKED/) work_blocked++
            
            # Count other events
            if ($0 ~ /HANDOFF:COMPLETED/) handoffs++
            if ($0 ~ /:DECISION\]/) decisions++
            if ($0 ~ /:MEMORY\]/) memories++
            if ($0 ~ /(ERROR|FAILED)/) errors++
        }
        
        END {
            print "Date Range: " first_date " to " last_date
            print "Total Events: " total_events
            print ""
            
            print "=== Persona Activity ==="
            for (p in personas) {
                if (personas[p] > 0) {
                    printf "%-12s: %3d initializations\n", p, personas[p]
                }
            }
            print "Total Inits : " total_inits
            print ""
            
            print "=== Work Items ==="
            actual_pending = work_pending - work_completed
            print "Pending     : " actual_pending " (net)"
            print "Started     : " work_started
            print "Completed   : " work_completed
            print "Blocked     : " work_blocked
            print ""
            
            print "=== Other Events ==="
            print "Handoffs    : " handoffs
            print "Decisions   : " decisions
            print "Memories    : " memories
            print "Errors      : " errors
            print ""
            
            # Calculate velocity
            if (total_events > 0) {
                print "=== Activity Metrics ==="
                print "Avg events/day: " int(total_events / 7)
                if (work_completed > 0 && handoffs > 0) {
                    print "Work items/handoff: " int(work_completed / handoffs)
                }
                if (total_inits > 0) {
                    print "Events/init: " int(total_events / total_inits)
                }
            }
        }
        ' "$JOURNAL_FILE"
        
        # Check for potential issues
        echo ""
        echo "=== Health Check ==="
        
        # Check for stuck personas
        for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
            recent_progress=$(tail -100 "$JOURNAL_FILE" | grep -c "WORK:COMPLETED.*$persona")
            recent_inits=$(tail -100 "$JOURNAL_FILE" | grep -c "$persona:INIT")
            
            if [ $recent_inits -gt 3 ] && [ $recent_progress -eq 0 ]; then
                echo "⚠️  $persona may be stuck (${recent_inits} inits, no completions)"
            fi
        done
        
        # Check journal size
        journal_size=$(wc -l < "$JOURNAL_FILE")
        if [ $journal_size -gt 10000 ]; then
            echo "⚠️  Journal is large ($journal_size lines) - consider archiving"
        fi
        
        echo ""
        echo "Use 'es-journal-query.sh stats all' to see complete history"
        ;;
        
    *)
        echo "Usage: es-journal-query.sh <query-type> [persona] [limit] [options]"
        echo ""
        echo "Query types:"
        echo "  pending-work          - Show pending work items"
        echo "  recent-context        - Show recent persona events"
        echo "  handoff-ready         - Check if ready for handoff"
        echo "  safety-check          - Check iteration limits"
        echo "  decisions             - Show architectural decisions"
        echo "  memory                - Show persistent memories"
        echo "  errors                - Show recent errors/blocks"
        echo "  work-history          - Show history for specific work"
        echo "  handoff-chain         - Show handoff history"
        echo "  current-persona       - Get current active persona"
        echo "  work-completed-persona - Get persona from most recent work completion"
        echo "  should-handoff        - Check if persona should hand off and to whom"
        echo "  work-summary          - Summary of work states"
        echo "  stats                 - Journal statistics (days-back as 4th param)"
        exit 1
        ;;
esac
