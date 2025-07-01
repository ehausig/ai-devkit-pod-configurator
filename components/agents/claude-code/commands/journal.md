---
allowed-tools: Bash(echo:*), Bash(date:*)
description: Add timestamped entries to the journal
---

Parse the arguments and add a journal entry:
- First argument should be the type (INFO, MILESTONE, DECISION, ERROR)
- All remaining arguments form the message

The bash command below will:
1. Extract the first argument as the type
2. Use all remaining arguments as the message
3. Add a timestamp
4. Append to ~/workspace/JOURNAL.md

!`args="$ARGUMENTS"; type=$(echo "$args" | cut -d' ' -f1); message=$(echo "$args" | cut -d' ' -f2-); echo "$(date -Iseconds) [$type] $message" >> ~/workspace/JOURNAL.md`

Confirm the journal entry was added.
