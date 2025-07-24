# Autonomous Development System

## Quick Start

Simply tell me what you want to build:
- "Create a REST API for a todo list in Python"
- "Build a web scraper in Node.js"
- "Develop a CLI tool in Rust"
- "Make a hello world app"

The system will automatically design, implement, test, review, and integrate your project through autonomous personas.

## How It Works

This is an **event-driven autonomous system** where development personas (ARCHITECT, DEVELOPER, QA, REVIEWER, MERGER) collaborate through journal events. Each persona:

1. **Monitors** the journal for assigned work
2. **Executes** their specialized tasks
3. **Hands off** to the next appropriate persona
4. **Logs** decisions and progress for visibility

## Starting a Project

When you request a new project, emit proper work assignments to the ARCHITECT:

```bash
# Example: Starting a "hello persona" Python project
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:$(date +%s)-1|WORK:Create system architecture for hello persona Python project"
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:$(date +%s)-2|WORK:Design API specification for persona interactions"
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:$(date +%s)-3|WORK:Define data models for persona system"
es-event-emit.sh "WORK_ASSIGNED" "TO:ARCHITECT|ID:$(date +%s)-4|WORK:Create testing strategy for persona behaviors"
```

The event monitor will detect these assignments and activate the ARCHITECT persona automatically.

## Event Format

Events must follow the format: `TYPE "KEY:VALUE|KEY:VALUE..."`

Key event types:
- `WORK_ASSIGNED` - Assign work to a persona (requires: TO, ID, WORK)
- `WORK_STARTED` - Persona begins work (requires: PERSONA, WORK_ID)
- `WORK_COMPLETED` - Work finished (requires: PERSONA, WORK_ID)
- `HANDOFF_READY` - Ready to hand off (requires: FROM, TO)

## Monitoring Progress

### Real-time Event Stream
```bash
tail -f ~/workspace/JOURNAL.md | grep EVENT
```

### Check System Status
```bash
es-projection.sh "" system_state
```

### View Specific Persona Status
```bash
es-projection.sh DEVELOPER current_state
es-projection.sh DEVELOPER pending_work
```

### See Recent Decisions
```bash
grep "DECISION\|MEMORY\|ISSUE" ~/workspace/JOURNAL.md | tail -20
```

## The Development Workflow

1. **ARCHITECT** - Creates system design and architecture
2. **DEVELOPER** - Implements code following TDD practices  
3. **QA** - Tests against real services (no mocks)
4. **REVIEWER** - Reviews code quality and compliance
5. **MERGER** - Integrates changes and manages releases

The workflow is **not linear** - personas can hand work back (e.g., REVIEWER → DEVELOPER for fixes).

## Key Commands

- `es-event-monitor.sh` - The autonomous event loop (starts automatically)
- `es-projection.sh [PERSONA] [VIEW]` - Query system state
- `es-event-emit.sh TYPE "FIELDS"` - Emit events (for debugging)

## Journal Structure

The `~/workspace/JOURNAL.md` file is the single source of truth using event sourcing:

- `[EVENT]` entries drive the autonomous system
- `[PERSONA:DECISION]` entries log architectural and implementation choices
- `[PERSONA:MEMORY]` entries capture important context
- `[PERSONA:ISSUE]` entries track problems and resolutions

## Troubleshooting

### System Not Starting?
Check if the event monitor is running:
```bash
ps aux | grep es-event-monitor.sh
```

### Work Not Progressing?
Check for pending work across all personas:
```bash
for p in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
  echo "$p: $(es-projection.sh $p pending_work | wc -l) pending"
done
```

### Need to Debug?
Enable debug output:
```bash
DEBUG=1 es-event-monitor.sh
```

## Important Notes

- The system runs **autonomously** - you don't need to manage personas
- All work is tracked through **events** in the journal
- Personas make **decisions** based on their specialized knowledge
- The journal provides **complete visibility** into the development process
- Events must use proper format: `TYPE "KEY:VALUE|KEY:VALUE..."`

---

*The autonomous system starts when you emit WORK_ASSIGNED events. Just describe your project and emit the events to watch the development unfold!*
