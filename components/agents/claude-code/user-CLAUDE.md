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
4. **Writes** NEXT_COMMAND to specify what happens next
5. **Invokes** the next persona directly before exiting

The self-chaining approach means each persona actively continues the workflow by reading NEXT_COMMAND events and invoking the appropriate next persona, creating true autonomy.

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
2024-01-15T10:15:02Z | NEXT_COMMAND | ARCHITECT | /developer
```

## Key Event: NEXT_COMMAND

The `NEXT_COMMAND` event drives autonomy:
- Each persona writes this event when completing work
- Each persona reads it before exiting and invokes the specified command
- This creates a self-sustaining development cycle
- Supports non-linear flows (e.g., REVIEWER → DEVELOPER for fixes)

Example flow:
```
NEXT_COMMAND | ARCHITECT | /developer    → ARCHITECT invokes /developer
NEXT_COMMAND | DEVELOPER | /qa          → DEVELOPER invokes /qa
NEXT_COMMAND | QA | /reviewer           → QA invokes /reviewer
NEXT_COMMAND | REVIEWER | /developer    → REVIEWER invokes /developer (fixes needed)
NEXT_COMMAND | DEVELOPER | /qa          → DEVELOPER invokes /qa (retest)
NEXT_COMMAND | QA | /reviewer           → QA invokes /reviewer (recheck)
NEXT_COMMAND | REVIEWER | /merger       → REVIEWER invokes /merger (approved)
```

## Development Workflow

1. **ARCHITECT** - Creates system design and architecture
2. **DEVELOPER** - Implements code following TDD practices  
3. **QA** - Tests against real services (no mocks)
4. **REVIEWER** - Reviews code quality and compliance
5. **MERGER** - Integrates changes and manages releases

The workflow is **not linear** - personas can hand work back (e.g., REVIEWER → DEVELOPER for fixes) using NEXT_COMMAND. Each persona invokes the next one directly, creating a self-sustaining chain of execution.

## Monitoring Progress

Use these commands to track development:
- `/show-journal` - See recent activity
- `/persona-status` - Check persona states
- `/event-query DEVELOPER WORK_ASSIGNED` - See Developer's pending work

## Important Notes

- The system runs **autonomously** after initialization through self-chaining
- All work is tracked through **events** in the journal
- Personas make **decisions** based on their specialized protocols
- Each persona **invokes the next** before exiting
- The journal provides **complete visibility** into the development process
- Context is preserved across Claude Code sessions
- The cycle completes when MERGER logs `CYCLE_COMPLETE`
- Supports **non-linear workflows** - personas can hand work backward or forward

---

*Start by describing your project, and I'll use `/init-project` to begin the autonomous development process!*
