#!/bin/bash
# Core journal query script - provides ephemeral views of journal data
# Usage: es-journal-query.sh <query-type> [persona] [limit] [options]

# Get parameters
query_type=$1
persona=${2:-$(grep "PERSONA:INIT" ~/workspace/JOURNAL.md 2>/dev/null | tail -1 | grep -o '\[.*:' | tr -d '[:[]' || echo "UNKNOWN")}
limit=${3:-20}

# Ensure journal exists
JOURNAL_FILE="${JOURNAL_FILE:-$HOME/workspace/JOURNAL.md}"
if [ ! -f "$JOURNAL_FILE" ]; then
    echo "No journal file found at $JOURNAL_FILE"
    exit 1
fi

case "$query_type" in
    "pending-work")
        # Get pending work for persona - FIXED: More robust pending work detection
        # Use a more sophisticated approach to track pending vs completed work
        
        # First, get all WORK:PENDING entries for this persona
        pending_items=$(grep "WORK:PENDING.*${persona}:" "$JOURNAL_FILE" 2>/dev/null)
        
        # For each pending item, check if it was completed
        echo "$pending_items" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                # Extract the work description (everything after WORK:PENDING] )
                work_desc=$(echo "$line" | sed 's/.*WORK:PENDING\] //')
                
                # Check if this exact work description appears in a WORK:COMPLETED entry
                # Use exact string matching with proper escaping for special characters
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
        # Check iteration count and recent progress - FIXED: Prevent double "0" output
        init_count=$(grep -c "\[${persona}:INIT\]" "$JOURNAL_FILE" 2>/dev/null)
        if [ -z "$init_count" ]; then
            init_count=0
        fi
        
        recent_progress=$(tail -100 "$JOURNAL_FILE" 2>/dev/null | grep -c "WORK:COMPLETED.*${persona}")
        if [ -z "$recent_progress" ]; then
            recent_progress=0
        fi
        
        # Always output the current status to stdout
        echo "Iterations: $init_count, Recent completions: $recent_progress"
        
        # Check for safety limits - FIXED: Send warnings to stderr and ensure proper exit codes
        if [ "$init_count" -gt 10 ]; then
            echo "WARNING: High iteration count ($init_count)" >&2
            exit 1
        fi
        
        if [ "$init_count" -gt 3 ] && [ "$recent_progress" -eq 0 ]; then
            echo "WARNING: No recent progress detected" >&2
            exit 2
        fi
        
        # Exit 0 for success (within limits)
        exit 0
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
        # Get the current active persona - FIXED: More robust extraction
        # Look for the most recent PERSONA:INIT entry
        last_init=$(grep "PERSONA:INIT" "$JOURNAL_FILE" 2>/dev/null | tail -1)
        
        if [ -n "$last_init" ]; then
            # Extract persona name from [PERSONA:INIT] format
            echo "$last_init" | sed 's/.*\[\([A-Z]*\):INIT\].*/\1/'
        else
            echo "UNKNOWN"
        fi
        ;;
        
    "work-completed-persona")
        # Extract persona from most recent WORK:COMPLETED entry - FIXED: More robust extraction
        # This handles various formats and should be more reliable
        recent_completed=$(grep "WORK:COMPLETED" "$JOURNAL_FILE" 2>/dev/null | tail -1)
        
        if [ -n "$recent_completed" ]; then
            # Try multiple extraction patterns
            # Pattern 1: "DEVELOPER: Task description"
            if echo "$recent_completed" | grep -q "WORK:COMPLETED\] [A-Z][A-Z]*:"; then
                echo "$recent_completed" | sed 's/.*WORK:COMPLETED\] \([A-Z][A-Z]*\):.*/\1/'
            # Pattern 2: Look for persona names in the description
            elif echo "$recent_completed" | grep -qE "(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)"; then
                echo "$recent_completed" | grep -oE "(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)" | head -1
            else
                # Fallback: empty result
                echo ""
            fi
        fi
        ;;
        
    "should-handoff")
        # Determine if a persona should hand off and to whom - FIXED: More robust logic
        # Usage: es-journal-query.sh should-handoff [persona]
        target_persona="${2:-$(es-journal-query.sh current-persona)}"
        
        # Ensure we have a valid persona
        if [ -z "$target_persona" ] || [ "$target_persona" = "UNKNOWN" ]; then
            exit 1
        fi
        
        pending=$(es-journal-query.sh pending-work "$target_persona" | wc -l)
        
        if [ "$pending" -eq 0 ]; then
            # No pending work, determine next persona based on current
            case "$target_persona" in
                ARCHITECT) echo "DEVELOPER" ;;
                DEVELOPER) 
                    # Check recent context for review feedback
                    if tail -50 "$JOURNAL_FILE" | grep -q "changes requested\|REVIEWER:ISSUE"; then
                        echo "QA"  # Still go to QA first, even if coming back from review
                    else
                        echo "QA"
                    fi
                    ;;
                QA)
                    # Check if tests passed based on recent QA context
                    failed=$(tail -50 "$JOURNAL_FILE" | grep -c "QA:FAILED" || echo "0")
                    issues=$(tail -50 "$JOURNAL_FILE" | grep -c "QA:ISSUE" || echo "0")
                    if [ "$failed" -eq 0 ] && [ "$issues" -eq 0 ]; then
                        echo "REVIEWER"
                    else
                        echo "DEVELOPER"
                    fi
                    ;;
                REVIEWER)
                    # Check if approved based on recent reviewer context
                    issues=$(tail -50 "$JOURNAL_FILE" | grep -c "REVIEWER:ISSUE" || echo "0")
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
        # Summary of work items by state - FIXED: Use exact string matching
        echo "=== Work Summary for $persona ==="
        
        # Count pending work more accurately
        pending_count=0
        pending_items=$(grep "WORK:PENDING.*${persona}:" "$JOURNAL_FILE" 2>/dev/null)
        if [ -n "$pending_items" ]; then
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    work_desc=$(echo "$line" | sed 's/.*WORK:PENDING\] //')
                    if ! grep -F "WORK:COMPLETED] $work_desc" "$JOURNAL_FILE" >/dev/null 2>&1; then
                        pending_count=$((pending_count + 1))
                    fi
                fi
            done <<< "$pending_items"
        fi
        
        echo "Pending: $pending_count"
        echo "Started: $(grep -c "WORK:STARTED.*${persona}:" "$JOURNAL_FILE" 2>/dev/null || echo "0")"
        echo "Completed: $(grep -c "WORK:COMPLETED.*${persona}:" "$JOURNAL_FILE" 2>/dev/null || echo "0")"
        echo "Blocked: $(grep -c "WORK:BLOCKED.*${persona}:" "$JOURNAL_FILE" 2>/dev/null || echo "0")"
        ;;

    "recent-handoff-unprocessed")
        # NEW: Get the most recent handoff that hasn't been processed yet
        # Look for HANDOFF:COMPLETED entries and check if target persona was subsequently initialized
        
        # Get all HANDOFF:COMPLETED entries with line numbers
        handoffs=$(grep -n "HANDOFF:COMPLETED" "$JOURNAL_FILE" 2>/dev/null)
        
        if [ -z "$handoffs" ]; then
            # No handoffs found
            exit 1
        fi
        
        # Process handoffs from most recent to oldest
        echo "$handoffs" | tac | while IFS= read -r handoff_line; do
            # Extract line number and content
            line_num=$(echo "$handoff_line" | cut -d: -f1)
            handoff_content=$(echo "$handoff_line" | cut -d: -f2-)
            
            # Extract target persona from handoff message
            target=$(es-journal-query.sh extract-handoff-target "" "" "$handoff_content" 2>/dev/null)
            
            if [ -n "$target" ] && [[ "$target" =~ ^(ARCHITECT|DEVELOPER|QA|REVIEWER|MERGER)$ ]]; then
                # Check if this target persona was initialized after this handoff
                subsequent_init=$(sed -n "${line_num},\$p" "$JOURNAL_FILE" | grep "\[${target}:INIT\]" | head -1)
                
                if [ -z "$subsequent_init" ]; then
                    # No subsequent initialization found - this handoff is unprocessed
                    echo "$target"
                    exit 0
                fi
            fi
        done
        
        # No unprocessed handoffs found
        exit 1
        ;;
        
    "extract-handoff-target")
        # NEW: Extract target persona from handoff message
        # Usage: es-journal-query.sh extract-handoff-target "" "" "message content"
        handoff_message="$4"
        
        if [ -z "$handoff_message" ]; then
            exit 1
        fi
        
        # Try multiple patterns to extract target persona
        # Pattern 1: "Handed off to PERSONA with X work items"
        if echo "$handoff_message" | grep -q "Handed off to [A-Z][A-Z]*"; then
            echo "$handoff_message" | sed 's/.*Handed off to \([A-Z][A-Z]*\).*/\1/'
            exit 0
        fi
        
        # Pattern 2: "handed off to PERSONA with X work items" (lowercase)
        if echo "$handoff_message" | grep -q "handed off to [A-Z][A-Z]*"; then
            echo "$handoff_message" | sed 's/.*handed off to \([A-Z][A-Z]*\).*/\1/'
            exit 0
        fi
        
        # Pattern 3: Direct persona names in the message
        for persona_name in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
            if echo "$handoff_message" | grep -q "$persona_name"; then
                echo "$persona_name"
                exit 0
            fi
        done
        
        # No target found
        exit 1
        ;;
        
    "handoff-processing-complete")
        # NEW: Check if the most recent handoff was processed (has subsequent PERSONA:INIT)
        # Usage: es-journal-query.sh handoff-processing-complete
        
        # Get the most recent handoff
        recent_handoff=$(grep "HANDOFF:COMPLETED" "$JOURNAL_FILE" 2>/dev/null | tail -1)
        
        if [ -z "$recent_handoff" ]; then
            # No handoffs found
            echo "no-handoffs"
            exit 0
        fi
        
        # Extract target persona
        target=$(es-journal-query.sh extract-handoff-target "" "" "$recent_handoff" 2>/dev/null)
        
        if [ -z "$target" ]; then
            # Could not extract target
            echo "extraction-failed"
            exit 1
        fi
        
        # Get line number of the handoff
        handoff_line=$(grep -n "HANDOFF:COMPLETED" "$JOURNAL_FILE" | tail -1 | cut -d: -f1)
        
        # Check for subsequent PERSONA:INIT for the target
        subsequent_init=$(sed -n "${handoff_line},\$p" "$JOURNAL_FILE" | grep "\[${target}:INIT\]" | head -1)
        
        if [ -n "$subsequent_init" ]; then
            echo "processed"
            exit 0
        else
            echo "unprocessed"
            exit 1
        fi
        ;;
        
    "transition-needed")
        # NEW: Comprehensive check if any transition is needed
        # Returns the target persona if transition is needed, empty if not
        
        # Priority 1: Check for unprocessed handoffs
        unprocessed_target=$(es-journal-query.sh recent-handoff-unprocessed 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$unprocessed_target" ]; then
            echo "$unprocessed_target"
            exit 0
        fi
        
        # Priority 2: Check for pending work across all personas (deterministic order)
        for persona_check in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
            pending_count=$(es-journal-query.sh pending-work "$persona_check" 2>/dev/null | wc -l)
            if [ "$pending_count" -gt 0 ]; then
                echo "$persona_check"
                exit 0
            fi
        done
        
        # Priority 3: Check if current persona should hand off
        current_persona=$(es-journal-query.sh current-persona)
        if [ -n "$current_persona" ] && [ "$current_persona" != "UNKNOWN" ]; then
            next_persona=$(es-journal-query.sh should-handoff "$current_persona" 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$next_persona" ]; then
                echo "$next_persona"
                exit 0
            fi
        fi
        
        # No transition needed
        exit 1
        ;;
        
    "last-persona-init")
        # NEW: Get the most recent persona initialization entry - FIXED
        # Returns the persona that was most recently initialized
        
        last_init=$(grep "\[.*:INIT\]" "$JOURNAL_FILE" 2>/dev/null | tail -1)
        
        if [ -n "$last_init" ]; then
            # Extract persona name - handle different formats
            # Look for [PERSONA:INIT] pattern and extract PERSONA part
            if echo "$last_init" | grep -q "\[[A-Z]*:INIT\]"; then
                echo "$last_init" | sed 's/.*\[\([A-Z]*\):INIT\].*/\1/'
                exit 0
            else
                echo "UNKNOWN"
                exit 1
            fi
        else
            echo "UNKNOWN"
            exit 1
        fi
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
        echo "  pending-work               - Show pending work items"
        echo "  recent-context             - Show recent persona events"
        echo "  handoff-ready              - Check if ready for handoff"
        echo "  safety-check               - Check iteration limits"
        echo "  decisions                  - Show architectural decisions"
        echo "  memory                     - Show persistent memories"
        echo "  errors                     - Show recent errors/blocks"
        echo "  work-history               - Show history for specific work"
        echo "  handoff-chain              - Show handoff history"
        echo "  current-persona            - Get current active persona"
        echo "  work-completed-persona     - Get persona from most recent work completion"
        echo "  should-handoff             - Check if persona should hand off and to whom"
        echo "  work-summary               - Summary of work states"
        echo "  stats                      - Journal statistics (days-back as 4th param)"
        echo ""
        echo "NEW EVENT-SOURCING QUERIES:"
        echo "  recent-handoff-unprocessed - Get latest unprocessed handoff target"
        echo "  extract-handoff-target     - Parse target persona from handoff message"
        echo "  handoff-processing-complete- Check if handoff was processed"
        echo "  transition-needed          - Determine if any transition is needed"
        echo "  last-persona-init          - Get most recent persona initialization"
        exit 1
        ;;
esac
