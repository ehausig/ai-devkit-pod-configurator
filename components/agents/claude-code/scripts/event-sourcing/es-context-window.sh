#!/bin/bash
# Get context window for a persona - shows relevant events since last handoff
# Usage: get-context-window <persona> [window-size]

persona=${1:-$(es-journal-query.sh current-persona)}
window_size=${2:-50}

JOURNAL_FILE="$HOME/workspace/JOURNAL.md"

if [ ! -f "$JOURNAL_FILE" ]; then
    echo "No journal file found"
    exit 1
fi

echo "=== Context Window for $persona ==="
echo ""

# Get last handoff point
last_handoff_line=$(grep -n "HANDOFF:COMPLETED.*to $persona" "$JOURNAL_FILE" 2>/dev/null | tail -1 | cut -d: -f1)

if [ -n "$last_handoff_line" ]; then
    echo "Context since handoff at line $last_handoff_line:"
    echo ""
    
    # Get everything since last handoff (up to window_size lines)
    tail -n +$last_handoff_line "$JOURNAL_FILE" | head -$window_size | \
        grep -E "(${persona}:|WORK:|HANDOFF:|DECISION:|MEMORY:)" | \
        while read -r line; do
            # Format output for readability
            timestamp=$(echo "$line" | cut -d' ' -f1)
            content=$(echo "$line" | cut -d' ' -f2-)
            
            # Color code by type
            if echo "$content" | grep -q "WORK:PENDING"; then
                echo -e "\033[33m$timestamp $content\033[0m"  # Yellow for pending
            elif echo "$content" | grep -q "WORK:COMPLETED"; then
                echo -e "\033[32m$timestamp $content\033[0m"  # Green for completed
            elif echo "$content" | grep -q "ERROR\|BLOCKED\|FAILED"; then
                echo -e "\033[31m$timestamp $content\033[0m"  # Red for errors
            else
                echo "$timestamp $content"
            fi
        done
else
    echo "No handoff found for $persona. Showing recent events:"
    echo ""
    
    # No handoff found, get recent persona events
    grep "\[${persona}:" "$JOURNAL_FILE" 2>/dev/null | tail -$window_size | \
        while read -r line; do
            timestamp=$(echo "$line" | cut -d' ' -f1)
            content=$(echo "$line" | cut -d' ' -f2-)
            echo "$timestamp $content"
        done
fi

echo ""
echo "=== Summary ==="
es-journal-query.sh work-summary "$persona"
