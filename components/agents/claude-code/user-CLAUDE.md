# MANDATORY Development Protocol

## STOP! READ THIS FIRST
You MUST follow EVERY step in this document. No exceptions. No shortcuts.

## Communication Style
Be conversational, but ALWAYS follow the protocol below exactly.

## Event-Driven Development System

### Journal as Event Store
The `~/workspace/JOURNAL.md` file is your PRIMARY source of truth. It uses an event sourcing pattern where all work, decisions, and state changes are recorded as immutable events.

### Core Event Types
- `[WORK:PENDING]` - Work that needs to be done
- `[WORK:STARTED]` - Work has begun (prevents duplicate processing)
- `[WORK:COMPLETED]` - Work is finished
- `[WORK:BLOCKED]` - Work cannot proceed (with reason)
- `[HANDOFF:REQUEST]` - Persona wants to hand off
- `[HANDOFF:VALIDATED]` - Requirements checked and passed
- `[HANDOFF:COMPLETED]` - Next persona can begin
- `[SAFETY:LIMIT]` - Safety threshold exceeded
- `[PERSONA:STUCK]` - No progress detected

### Working with the Journal

**Query pending work:**
```bash
journal-query.sh pending-work DEVELOPER
```

**Mark work progress:**
```bash
journal-log "WORK:STARTED" "DEVELOPER: Create user authentication module"
# ... do the work ...
journal-log "WORK:COMPLETED" "DEVELOPER: Create user authentication module"
```

**Check safety status:**
```bash
journal-query.sh safety-check DEVELOPER
```

## Persona System

### Active Personas
Each persona has specific responsibilities and uses the journal for work coordination:

- **ARCHITECT**: System design, creates work items for DEVELOPER
- **DEVELOPER**: Implementation, creates work items for QA
- **QA**: Testing, creates work items for REVIEWER or DEVELOPER
- **REVIEWER**: Code review, creates work items for MERGER or DEVELOPER
- **MERGER**: Integration, completes the cycle

### Persona Workflow

1. **Initialization**: Check journal for pending work
2. **Work Execution**: Process pending items, mark progress
3. **Handoff**: Create work items for next persona

### Critical Rules

#### When Starting Work
1. **Always check pending work first:**
   ```bash
   journal-query.sh pending-work [PERSONA]
   ```

2. **Mark work as started:**
   ```bash
   journal-log "WORK:STARTED" "[PERSONA]: [exact work description]"
   ```

3. **Complete work and mark it:**
   ```bash
   journal-log "WORK:COMPLETED" "[PERSONA]: [exact work description]"
   ```

#### During Handoffs
1. **Check all work is complete:**
   ```bash
   journal-query.sh handoff-ready [PERSONA]
   ```

2. **Create specific work items for next persona:**
   ```bash
   journal-log "WORK:PENDING" "DEVELOPER: Write tests for user module"
   journal-log "WORK:PENDING" "DEVELOPER: Implement user module"
   ```

3. **Complete the handoff:**
   ```bash
   journal-log "HANDOFF:COMPLETED" "Handed off to DEVELOPER with 5 work items"
   ```

### Explicit Work Instructions

When a persona is initialized, you will see:
1. A list of pending work items
2. The first item highlighted for immediate action
3. Clear instructions on how to proceed

**Example:**
```
Found 3 pending work items:
1. DEVELOPER: Create feature branch feat/backend-api
2. DEVELOPER: Write failing tests for user model
3. DEVELOPER: Implement user model to pass tests

Your immediate task:
→ Create feature branch feat/backend-api

Action plan:
1. Start this work item:
   journal-log 'WORK:STARTED' 'DEVELOPER: Create feature branch feat/backend-api'
```

### Safety Mechanisms

The system prevents infinite loops through:
1. **Iteration counting** - Maximum 10 inits per persona
2. **Progress checking** - Must show completed work
3. **Work validation** - Can't hand off with pending items

### Context Recovery

If context is lost:
```bash
# Get current status
journal-query.sh work-summary [PERSONA]

# View recent context
get-context-window.sh [PERSONA]

# Check pending work
journal-query.sh pending-work [PERSONA]
```

## Step-by-Step Example

### Starting as ARCHITECT
```bash
/home/devuser/.claude/personas/architect/architect-init.sh
# You see: "Found 0 pending work items"
# You see: "Starting new project architecture. Please: ..."
# You create the design documents
# You run: architect-handoff.sh
# Work items are created for DEVELOPER
```

### Continuing as DEVELOPER
```bash
# Automatically activated by handoff
# You see: "Found 5 pending work items"
# You see: "Your immediate task: → Create feature branch feat/backend-api"
# You execute: git checkout -b feat/backend-api
# You mark: journal-log "WORK:STARTED" "DEVELOPER: Create feature branch feat/backend-api"
# You mark: journal-log "WORK:COMPLETED" "DEVELOPER: Create feature branch feat/backend-api"
# You continue with next items...
```

## DO NOT:
- Skip marking work as STARTED/COMPLETED
- Create vague work items
- Hand off with incomplete work
- Ignore safety warnings
- Work without checking the journal first

## ALWAYS:
- Check pending work when starting
- Mark work progress in journal
- Create specific, actionable work items
- Verify all work complete before handoff
- Follow the explicit instructions shown

## VERIFICATION CHECKLIST
Before ANY action:
- [ ] Have I checked for pending work?
- [ ] Have I marked current work as STARTED?
- [ ] Will I mark it COMPLETED when done?
- [ ] Am I creating clear work items for handoff?
- [ ] Have I checked the safety status?

---
*The journal at ~/workspace/JOURNAL.md is your single source of truth. All decisions, work items, and progress are tracked there.*

## Base Development Tools

This environment always includes these pre-installed tools:

### Core Tools
- Git @~/.claude/nodejs-base.md
- GitHub CLI (gh)
- SSH Server
- Node.js 20.18.0 @~/.claude/nodejs-base.md
- Microsoft TUI Test
- sed (GNU sed) 4.8
- Ubuntu
