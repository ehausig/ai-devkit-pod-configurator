---
description: Initialize autonomous development project with sub agents
---

# Initialize Autonomous Project

Start a new project using the autonomous sub agent development system.

## Process

When the user requests to create a project, I will:

1. **Parse the request** to determine:
   - Project type and requirements
   - Whether requirements are clear enough
   - Starting agent (product-manager for vague, architect for clear)

2. **Create the journal** at `~/workspace/JOURNAL.md`

3. **Add initial events**:
   - PROJECT_INIT event
   - WORK_ASSIGNED for the first agent
   - NEXT_AGENT directive

4. **Instruct delegation** to begin autonomous flow

## Decision Logic

- **Vague requests** → Start with product-manager
  - "Create a chat app"
  - "Build something for task management"
  - "I need a tool for X"

- **Clear technical requests** → Start with architect
  - "Create a REST API with CRUD operations for todos"
  - "Build a CLI tool in Rust that converts JSON to YAML"

## Journal Format

```
TIMESTAMP | EVENT_TYPE | DETAILS
```

Example initialization:
```
2024-01-20T10:00:00Z | PROJECT_INIT | Starting chat application
2024-01-20T10:00:01Z | WORK_ASSIGNED | PRODUCT_MANAGER | Define requirements for chat app
2024-01-20T10:00:02Z | NEXT_AGENT | system | product-manager | Requirements analysis needed
```

## Delegation Message

After creating the journal, I will say:

"I've initialized the autonomous development system. Please delegate to the [agent-name] agent to begin."

The Stop hook will then automatically continue the process.

## Usage

Simply describe what you want to build, then use:
```
/init-autonomous
```

The system will determine the appropriate starting point and begin the autonomous development cycle.
