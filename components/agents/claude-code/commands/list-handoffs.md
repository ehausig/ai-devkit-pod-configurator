---
description: List all pending handoffs between personas
---

# List Pending Handoffs

Show all pending work handoffs between personas.

## Usage

```
/list-handoffs
```

## Instructions

1. Search journal for all HANDOFF entries
2. Identify which are still pending
3. Group by target persona
4. Show summary of work to be done

## Example Commands

```bash
# Show all recent handoffs
grep "HANDOFF" ~/workspace/JOURNAL.md | tail -20

# Show handoffs by persona
echo "=== Pending for ARCHITECT ==="
grep "HANDOFF.*ARCHITECT" ~/workspace/JOURNAL.md | tail -5

echo -e "\n=== Pending for DEVELOPER ==="
grep "HANDOFF.*DEVELOPER" ~/workspace/JOURNAL.md | tail -5

echo -e "\n=== Pending for QA ==="
grep "HANDOFF.*QA" ~/workspace/JOURNAL.md | tail -5

echo -e "\n=== Pending for REVIEWER ==="
grep "HANDOFF.*REVIEWER" ~/workspace/JOURNAL.md | tail -5

echo -e "\n=== Pending for MERGER ==="
grep "HANDOFF.*MERGER" ~/workspace/JOURNAL.md | tail -5

# Check for handoff documents
ls -la HANDOFF_TO_*.md 2>/dev/null || echo "No handoff documents found"
```
