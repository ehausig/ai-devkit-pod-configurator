---
description: Display recent journal entries
---

# Show Journal

Display recent entries from the development journal with formatting.

## Usage

`/show-journal [lines]`

## Examples

```bash
# Show last 20 entries (default)
/show-journal

# Show last 50 entries
/show-journal 50

# Show all entries
/show-journal all
```

## Implementation

```bash
# Parse arguments
LINES="${1:-20}"

# Check if journal exists
if [ ! -f ~/workspace/JOURNAL.md ]; then
    echo "No journal found. Start a project with /init-project"
    exit 1
fi

echo "=== Development Journal ==="
echo ""

# Show entries based on argument
if [ "$LINES" = "all" ]; then
    cat ~/workspace/JOURNAL.md | grep -v "^#" | grep -v "^$"
else
    # Show last N lines that contain events
    grep " | " ~/workspace/JOURNAL.md | tail -"$LINES" | while IFS='|' read -r timestamp type persona description; do
        # Trim whitespace
        timestamp=$(echo "$timestamp" | xargs)
        type=$(echo "$type" | xargs)
        persona=$(echo "$persona" | xargs)
        description=$(echo "$description" | xargs)
        
        # Format timestamp for readability (just time if today)
        today=$(date -u +"%Y-%m-%d")
        if [[ "$timestamp" =~ ^$today ]]; then
            display_time=$(echo "$timestamp" | cut -d'T' -f2 | cut -d'Z' -f1)
        else
            display_time="$timestamp"
        fi
        
        # Color code by event type
        case "$type" in
            WORK_ASSIGNED)
                echo "[$display_time] 📋 $persona: $description"
                ;;
            WORK_STARTED)
                echo "[$display_time] 🚀 $persona: Started - $description"
                ;;
            WORK_COMPLETE)
                echo "[$display_time] ✅ $persona: $description"
                ;;
            HANDOFF)
                echo "[$display_time] 🤝 $persona: $description"
                ;;
            DECISION)
                echo "[$display_time] 🎯 $persona: $description"
                ;;
            FILE_CREATED|FILE_UPDATED)
                echo "[$display_time] 📄 $persona: $description"
                ;;
            TEST_RESULT|TEST_COVERAGE)
                echo "[$display_time] 🧪 $persona: $description"
                ;;
            QA_ISSUE|REVIEW_ISSUE)
                echo "[$display_time] ⚠️  $persona: $description"
                ;;
            PROJECT_INIT)
                echo "[$display_time] 🏁 $persona: $description"
                ;;
            CYCLE_COMPLETE)
                echo "[$display_time] 🎉 $persona: $description"
                ;;
            *)
                echo "[$display_time] $type - $persona: $description"
                ;;
        esac
    done
fi

# Show summary statistics
echo ""
echo "=== Journal Statistics ==="
TOTAL_EVENTS=$(grep -c " | " ~/workspace/JOURNAL.md)
echo "Total events: $TOTAL_EVENTS"

# Count by persona
for P in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    COUNT=$(grep -c " | $P | " ~/workspace/JOURNAL.md)
    if [ $COUNT -gt 0 ]; then
        echo "$P: $COUNT events"
    fi
done

# Show current state
echo ""
echo "=== Current State ==="
# Find last handoff
LAST_HANDOFF=$(grep "HANDOFF |" ~/workspace/JOURNAL.md | tail -1)
if [ -n "$LAST_HANDOFF" ]; then
    echo "Last handoff: $(echo "$LAST_HANDOFF" | cut -d'|' -f3-)"
fi

# Check if cycle is complete
if grep -q "CYCLE_COMPLETE" ~/workspace/JOURNAL.md; then
    echo "Status: Development cycle COMPLETE ✓"
else
    echo "Status: Development in progress..."
    
    # Show active persona (last one with work assigned but not all complete)
    for P in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
        ASSIGNED=$(grep -c "WORK_ASSIGNED | $P" ~/workspace/JOURNAL.md)
        COMPLETE=$(grep -c "WORK_COMPLETE | $P" ~/workspace/JOURNAL.md)
        if [ $ASSIGNED -gt $COMPLETE ]; then
            echo "Active persona: $P ($(($ASSIGNED - $COMPLETE)) pending tasks)"
            break
        fi
    done
fi
```

## Display Features

- Timestamps shown in brackets
- Emoji indicators for event types:
  - 📋 Work assigned
  - ✅ Work complete
  - 🤝 Handoff
  - 🎯 Decision
  - 📄 File created/updated
  - 🧪 Test result
  - ⚠️ Issue found
  - 🎉 Cycle complete

## Notes

- Default shows last 20 events
- Use 'all' to see complete history
- Includes statistics and current state
- Formatted for easy readability
