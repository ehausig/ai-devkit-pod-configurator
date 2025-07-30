# Claude Code Scripts

This directory contains utility scripts for the Claude Code autonomous development system.

## Overview

These bash scripts provide core functionality for the Kanban-based workflow and event tracking system.

## Available Scripts

### `journal-log.sh`
Logs events to the development journal (JOURNAL.md).

**Usage:**
```bash
journal-log.sh EVENT_TYPE ACTOR "Description message"
```

**Example:**
```bash
journal-log.sh CARD_CREATED "PM" "CARD-001 | Setup development environment | BACKLOG"
journal-log.sh WORK_PROGRESS "developer" "Implemented user authentication"
```

**Common Event Types:**
- `PROJECT_INIT` - Project initialization
- `CARD_CREATED` - New Kanban card
- `CARD_UPDATED` - Card state change
- `WORK_ASSIGNED` - Work assigned to agent
- `WORK_PROGRESS` - Progress update
- `WORK_COMPLETE` - Task completed
- `DECISION` - Technical decision made
- `TEST_RESULT` - Test execution results

### `generate-card-id.sh`
Generates sequential three-digit IDs for Kanban cards.

**Usage:**
```bash
CARD_ID=$(generate-card-id.sh)
echo "Created card: CARD-$CARD_ID"
```

**Features:**
- Sequential numbering (001, 002, 003...)
- Persistent counter in `/tmp/ai-devkit-card-counter`
- Thread-safe for concurrent use
- Always returns 3-digit formatted ID

## How Scripts Work

1. **Installation**: Scripts are copied to `~/.claude/scripts/` during build
2. **PATH Setup**: Symlinked to `/usr/local/bin/` for global access
3. **Permissions**: Made executable during setup
4. **Usage**: Available to all agents and commands

## Integration with Autonomous System

These scripts are fundamental to:
- **State Management** - All state changes logged to JOURNAL.md
- **Card Tracking** - Unique IDs for work items
- **Agent Communication** - Shared journal for handoffs
- **Audit Trail** - Complete development history

## Script Standards

All scripts follow these conventions:
- Written in bash for portability
- Use strict error handling (`set -e` implied)
- Accept standard arguments
- Return appropriate exit codes
- Output to stdout/stderr appropriately

## Creating New Scripts

To add a utility script:

1. Create `.sh` file with descriptive name
2. Add shebang: `#!/bin/bash`
3. Include usage documentation
4. Handle errors gracefully
5. Make executable: `chmod +x script.sh`
6. Test thoroughly

## Best Practices

- **Idempotent** - Safe to run multiple times
- **Atomic** - Complete operations fully or not at all
- **Logged** - Important actions logged to journal
- **Validated** - Check inputs and prerequisites
- **Documented** - Clear usage instructions

## Example: Custom Script

```bash
#!/bin/bash
# my-utility.sh - Description of what it does

# Usage check
if [ $# -lt 1 ]; then
    echo "Usage: my-utility.sh <argument>"
    exit 1
fi

# Your logic here
ARG="$1"
echo "Processing: $ARG"

# Log significant events
journal-log.sh CUSTOM_EVENT "my-utility" "Processed $ARG successfully"

exit 0
```

## Debugging

To debug scripts:
```bash
# Run with bash debug mode
bash -x script.sh arguments

# Check journal for entries
grep "script-name" ~/workspace/JOURNAL.md

# Verify counter state
cat /tmp/ai-devkit-card-counter
```

See the main [Claude Code README](../README.md) for more details on the autonomous development system.
