# Claude Code Commands

This directory contains custom slash commands for the Claude Code autonomous development system.

## Overview

Each `.md` file defines a command that can be invoked with `/command-name` in Claude Code. These commands provide utilities for managing the autonomous development workflow.

## Available Commands

### Core Autonomous Commands

- **`/init-autonomous`** - Initialize a new autonomous development project
  - Reads requirements from `~/workspace/PROMPT.md`
  - Creates initial Kanban cards
  - Starts the Product Manager orchestration

- **`/create-prompt`** - Interactive requirements gathering
  - Delegates to requirements-analyst agent
  - Guides through project specification
  - Creates structured PROMPT.md file

### Monitoring Commands

- **`/show-journal`** - Display the development journal
  - Shows recent events with formatting
  - Tracks agent activities and handoffs
  - Displays Kanban card state changes

- **`/kanban-status`** - View current Kanban board state
  - Shows all cards organized by state
  - Displays current assignments
  - Identifies blockers and progress

- **`/event-query [type]`** - Query specific journal events
  - Filter by event type (e.g., CARD_, WORK_)
  - Useful for tracking specific activities
  - Provides summary statistics

## Command File Format

Each command file has:

```markdown
---
description: Brief description of what the command does
---

# Command Name

Detailed explanation of the command's purpose and usage.

## Process

What the command does when invoked...

## Usage

Examples of how to use the command...
```

## How Commands Work

1. Commands are copied to `~/.claude/commands/` during build
2. Claude Code recognizes them as slash commands
3. When invoked, Claude follows the instructions in the file
4. Commands can delegate to agents or perform direct actions

## Creating New Commands

To add a new command:

1. Create a `.md` file named after your command
2. Add frontmatter with description
3. Document the command's behavior
4. Include usage examples
5. Test in Claude Code

## Best Practices

- Keep commands focused on a single purpose
- Provide clear usage examples
- Document any prerequisites
- Include error handling guidance
- Make commands idempotent when possible

## Integration Points

Commands integrate with:
- JOURNAL.md for state tracking
- Kanban card system
- Agent delegation
- File system operations
- External tools

## Command Categories

### Project Management
- Initialization and setup
- Status and monitoring
- Workflow control

### Development Support
- Code generation helpers
- Testing utilities
- Documentation tools

### System Utilities
- File management
- Environment setup
- Tool integration

See the main [Claude Code README](../README.md) for more details on using these commands.
