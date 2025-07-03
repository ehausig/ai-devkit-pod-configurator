#!/bin/bash
# Track work item lifecycle through the journal
# Usage: work-tracker.sh <work-pattern> [persona]

work_pattern="$1"
persona="${2:-ALL}"

if [ -z "$work_pattern" ]; then
    echo "Usage: work-tracker.sh <work-pattern> [persona]"
    echo "Example: work-tracker.sh 'greeter module' DEVELOPER"
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
            # Extract work description
            match($0, /WORK:PENDING\] (.+)/, arr)
            work_desc = arr[1]
            
            # Extract persona from description
            if (match(work_desc, /^([A-Z]+): (.+)/, parts)) {
                persona = parts[1]
                task = parts[2]
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
    else if ($0 ~ /WORK:STARTED/) {
        match($0, /WORK:STARTED\] (.+)/, arr)
        work_desc = arr[1]
        work_id = substr(work_desc, 1, 50)
        
        if (work_id in pending) {
            started[work_id] = timestamp
            print BLUE "→ STARTED" RESET " [" timestamp "] " work_desc
        }
    }
    else if ($0 ~ /WORK:COMPLETED/) {
        match($0, /WORK:COMPLETED\] (.+)/, arr)
        work_desc = arr[1]
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
    else if ($0 ~ /WORK:BLOCKED/) {
        match($0, /WORK:BLOCKED\] (.+)/, arr)
        work_desc = arr[1]
        work_id = substr(work_desc, 1, 50)
        
        if (work_id in pending) {
            blocked[work_id] = timestamp
            print RED "✗ BLOCKED" RESET " [" timestamp "] " work_desc
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
