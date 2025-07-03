---
description: Show journal status and pending work across all personas
---

# Journal Summary

Display the current state of the journal-based work system.

## Usage

```
/journal-summary
```

## Instructions

1. Show overall journal statistics
2. Display pending work for each persona
3. Check safety status for all personas
4. Show recent handoffs

## Example Commands

```bash
# Overall statistics
journal-stats.sh 1

# Check each persona's pending work
echo "=== Pending Work by Persona ==="
for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    echo ""
    echo "$persona:"
    journal-query.sh pending-work $persona | head -5
done

# Recent handoff chain
echo ""
echo "=== Recent Handoffs ==="
journal-query.sh handoff-chain | tail -5

# Current active persona
echo ""
echo "=== Current Active Persona ==="
journal-query.sh current-persona

# Safety status check
echo ""
echo "=== Safety Status ==="
for persona in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
    echo -n "$persona: "
    journal-query.sh safety-check $persona
done
```
