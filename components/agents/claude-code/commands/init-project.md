---
description: Initialize a new autonomous development project
---

# Initialize Autonomous Project

Start a new project using the event-driven autonomous development system.

## Process

When the user requests to create a project, I will:

1. **Parse the request** to extract:
   - Project name (e.g., "hello world", "todo list")
   - Project type (e.g., "application", "REST API", "CLI tool")
   - Language (e.g., "Python", "Node.js", "Rust")

2. **Create or update the journal** at `~/workspace/JOURNAL.md` using the Write tool

3. **Add initial events**:
   - PROJECT_INIT event to mark the start
   - WORK_ASSIGNED event for the ARCHITECT
   - NEXT_COMMAND event to trigger the architect persona

4. **Invoke the architect persona** - Continue the autonomous workflow

## Autonomous Continuation

After creating the journal with initial work assignments, I will:

1. Read the NEXT_COMMAND event from the journal (which will be /architect)
2. Immediately invoke the architect command to continue the autonomous workflow

The architect persona will then complete its work and invoke the next persona, creating a self-sustaining chain until CYCLE_COMPLETE is logged.

## Journal Format

Events are pipe-delimited with timestamps:
```
TIMESTAMP | EVENT_TYPE | PERSONA | DESCRIPTION
```

Example:
```
2024-01-15T10:00:00Z | PROJECT_INIT | SYSTEM | Starting hello world project in Python
2024-01-15T10:00:01Z | WORK_ASSIGNED | ARCHITECT | Design hello world application in Python
2024-01-15T10:00:02Z | NEXT_COMMAND | SYSTEM | /architect
```

## How It Works

After initialization:
1. I will create the journal with initial events including NEXT_COMMAND
2. I will read the NEXT_COMMAND and invoke the architect persona
3. Each persona will complete their work and invoke the next persona
4. This creates a self-sustaining chain until CYCLE_COMPLETE
5. No user intervention needed after initialization

The orchestration happens through each persona reading NEXT_COMMAND and invoking the next persona directly.

## Example Patterns

- "create a hello world project in Python"
- "build a REST API for todo management"
- "develop a web scraper in Node.js"
- "make a CLI tool in Rust"

The system adapts to the project type and language specified.
