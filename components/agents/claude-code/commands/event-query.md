---
description: Query events from the development journal
---

# Event Query

Query and filter events from the development journal.

## Usage

`/event-query [persona] [type]`

## Examples

```bash
# Show all events
/event-query

# Show events for a specific persona
/event-query DEVELOPER

# Show events of a specific type
/event-query "" WORK_ASSIGNED

# Show DEVELOPER's completed work
/event-query DEVELOPER WORK_COMPLETE

# Show all handoffs
/event-query "" HANDOFF

# Show all decisions
/event-query ARCHITECT DECISION
```

## Implementation

```bash
# Parse arguments
PERSONA="${1:-}"
EVENT_TYPE="${2:-}"

# Check if journal exists
if [ ! -f ~/workspace/JOURNAL.md ]; then
    echo "No journal found. Start a project with /init-project"
    exit 1
fi

# Build grep pattern
PATTERN=""
if [ -n "$PERSONA" ] && [ -n "$EVENT_TYPE" ]; then
    PATTERN="$EVENT_TYPE | $PERSONA"
elif [ -n "$PERSONA" ]; then
    PATTERN=" | $PERSONA | "
elif [ -n "$EVENT_TYPE" ]; then
    PATTERN=" | $EVENT_TYPE | "
fi

# Query events
echo "=== Event Query Results ==="
echo ""

if [ -z "$PATTERN" ]; then
    # Show all events
    grep " | " ~/workspace/JOURNAL.md | tail -20
else
    # Show filtered events
    grep "$PATTERN" ~/workspace/JOURNAL.md | tail -20
fi

# Show summary
echo ""
echo "=== Summary ==="
if [ -n "$PERSONA" ]; then
    TOTAL=$(grep " | $PERSONA | " ~/workspace/JOURNAL.md | wc -l)
    echo "$PERSONA total events: $TOTAL"
fi

if [ -n "$EVENT_TYPE" ]; then
    TYPE_TOTAL=$(grep " | $EVENT_TYPE | " ~/workspace/JOURNAL.md | wc -l)
    echo "$EVENT_TYPE total: $TYPE_TOTAL"
fi
```

## Query Patterns

Useful queries for monitoring progress:

```bash
# Show pending work for each persona
for P in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    ASSIGNED=$(grep "WORK_ASSIGNED | $P" ~/workspace/JOURNAL.md | wc -l)
    COMPLETE=$(grep "WORK_COMPLETE | $P" ~/workspace/JOURNAL.md | wc -l)
    PENDING=$((ASSIGNED - COMPLETE))
    echo "$P: $PENDING pending tasks"
done

# Show handoff flow
grep "HANDOFF |" ~/workspace/JOURNAL.md | tail -10

# Show recent decisions
grep "DECISION |" ~/workspace/JOURNAL.md | tail -10

# Show test results
grep -E "TEST_RESULT|TEST_COVERAGE" ~/workspace/JOURNAL.md
```

## Notes

- Queries show the most recent 20 events by default
- Use grep patterns for more complex queries
- The journal maintains complete history
- Events are shown in chronological order
