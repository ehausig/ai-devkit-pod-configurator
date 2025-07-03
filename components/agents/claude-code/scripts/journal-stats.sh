#!/bin/bash
# Get journal statistics without loading full file
# Usage: journal-stats.sh [days-back]

days_back=${1:-7}
JOURNAL_FILE="$HOME/workspace/JOURNAL.md"

if [ ! -f "$JOURNAL_FILE" ]; then
    echo "No journal file found"
    exit 1
fi

# Calculate cutoff date
if [ "$days_back" = "all" ]; then
    cutoff_date="1970-01-01"
else
    cutoff_date=$(date -d "$days_back days ago" +%Y-%m-%d)
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
echo "Use 'journal-stats.sh all' to see complete history"
