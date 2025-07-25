# Autonomous Development System

## Quick Start

Simply tell me what you want to build:
- "Please initiate the architect persona and create a 'hello world' project in Python"
- "Create a REST API for a todo list"
- "Build a web scraper in Node.js"
- "Develop a CLI tool in Rust"

The system will autonomously design, implement, test, review, and integrate your project through specialized personas.

## How It Works

This system uses **event-driven development** where personas (ARCHITECT, DEVELOPER, QA, REVIEWER, MERGER) collaborate through a persistent journal. Each persona:

1. **Reads** assigned work from the journal
2. **Performs** specialized tasks
3. **Records** decisions and completions
4. **Hands off** to the next appropriate persona

## Available Commands

### Project Initialization
- `/init-project` - Parse your request and start the development process

### Persona Commands
- `/architect` - System design and architecture
- `/developer` - Implementation and coding
- `/qa` - Testing and quality assurance
- `/reviewer` - Code review and approval
- `/merger` - Integration and release

### Utility Commands
- `/event-emit <type> <persona> <description>` - Add events to journal
- `/event-query [persona] [type]` - Query journal state
- `/show-journal` - Display recent journal entries
- `/persona-status` - Show current state of all personas

## Journal Structure

The `~/workspace/JOURNAL.md` file tracks all development activities:

```
2024-01-15T10:00:00Z | WORK_ASSIGNED | ARCHITECT | Create hello world Python project
2024-01-15T10:05:00Z | DECISION | ARCHITECT | Using Flask for web framework
2024-01-15T10:10:00Z | FILE_CREATED | ARCHITECT | ARCHITECTURE.md
2024-01-15T10:15:00Z | WORK_COMPLETE | ARCHITECT | Architecture phase complete
2024-01-15T10:15:01Z | HANDOFF | ARCHITECT->DEVELOPER | 4 implementation tasks
```

## Development Workflow

1. **ARCHITECT** - Creates system design and architecture
2. **DEVELOPER** - Implements code following TDD practices  
3. **QA** - Tests against real services (no mocks)
4. **REVIEWER** - Reviews code quality and compliance
5. **MERGER** - Integrates changes and manages releases

The workflow is **not linear** - personas can hand work back (e.g., REVIEWER → DEVELOPER for fixes).

## Monitoring Progress

Use these commands to track development:
- `/show-journal` - See recent activity
- `/persona-status` - Check persona states
- `/event-query DEVELOPER WORK_ASSIGNED` - See Developer's pending work

## Important Notes

- The system runs **autonomously** after initialization
- All work is tracked through **events** in the journal
- Personas make **decisions** based on their specialized protocols
- The journal provides **complete visibility** into the development process
- Context is preserved across Claude Code sessions

---

*Start by describing your project, and I'll use `/init-project` to begin the autonomous development process!*
