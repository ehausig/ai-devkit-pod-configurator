---
description: Read ~/workspace/PROMPT.md if it exists
---

# Read PROMPT.md File

Check if ~/workspace/PROMPT.md exists and display its contents.

## Instructions

Simply read the file if it exists:

```bash
if [ -f ~/workspace/PROMPT.md ]; then
    cat ~/workspace/PROMPT.md
else
    echo "File not found: ~/workspace/PROMPT.md"
fi
```
