# Claude Code Hooks

This directory is for optional Claude Code hook scripts.

## Overview

While the autonomous development system **does not rely on hooks** for its core orchestration (it uses explicit Product Manager control instead), hooks can be useful for specific workflows or integrations.

## Important Note

The autonomous development system works through:
- Explicit orchestration by the Product Manager (main thread)
- Deterministic handoffs via JOURNAL.md
- Kanban card state management
- Direct agent delegation

Hooks are **optional** and should not be used for core workflow control.

## When to Use Hooks

Hooks might be useful for:
- Code formatting after file changes
- Running linters automatically
- Notifying external systems
- Custom logging or metrics
- Integration with third-party tools

## Hook Types (If Used)

Claude Code supports these hook events:
- `PreToolUse` - Before tool execution
- `PostToolUse` - After tool execution
- `UserPromptSubmit` - When user submits prompt
- `Stop` - When Claude finishes responding
- `SessionStart` - When session begins

## Example Hook Structure

If you need to add a hook:

```bash
#!/bin/bash
# hooks/example-hook.sh

# Read input from stdin
input=$(cat)

# Process as needed
echo "Hook processing..." >&2

# Exit with appropriate code
# 0 = success, continue
# 2 = block action (for some hooks)
exit 0
```

## Configuration

Hooks would be configured in settings.json (not used by default):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/format-code.sh"
        }]
      }
    ]
  }
}
```

## Why Hooks Are Optional

The autonomous system achieves reliability through:
1. **Explicit Control** - PM manages all workflows
2. **State Persistence** - JOURNAL.md tracks everything
3. **Clear Handoffs** - No implicit behaviors
4. **Debugging** - Easy to trace execution

## Best Practices

If you do use hooks:
- Keep them simple and fast
- Make them idempotent
- Handle errors gracefully
- Don't use for core workflow logic
- Document their purpose clearly

## Alternatives to Hooks

Instead of hooks, consider:
- Adding steps to agent workflows
- Creating new commands
- Updating agent instructions
- Using explicit tool calls

See the main [Claude Code README](../README.md) for details on the hook-free autonomous orchestration system.
