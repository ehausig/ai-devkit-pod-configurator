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

## Monitoring Progress

### Real-time Event Stream
```bash
tail -f ~/workspace/JOURNAL.md | grep EVENT
```

### Check System Status
```bash
es-projection "" system_state
```

### View Specific Persona Status
```bash
es-projection DEVELOPER current_state
es-projection DEVELOPER pending_work
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

- `es-event-monitor` - The autonomous event loop (starts automatically)
- `es-projection [PERSONA] [VIEW]` - Query system state
- `es-event-emit TYPE "FIELDS"` - Emit events (for debugging)

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
ps aux | grep es-event-monitor
```

### Work Not Progressing?
Check for pending work across all personas:
```bash
for p in ARCHITECT DEVELOPER QA REVIEWER MERGER; do
  echo "$p: $(es-projection $p pending_work | wc -l) pending"
done
```

### Need to Debug?
Enable debug output:
```bash
DEBUG=1 es-event-monitor
```

## Important Notes

- The system runs **autonomously** - you don't need to manage personas
- All work is tracked through **events** in the journal
- Personas make **decisions** based on their specialized knowledge
- The journal provides **complete visibility** into the development process

---

*The autonomous system starts when you describe what you want to build. Just tell me your requirements and watch the development unfold!*
