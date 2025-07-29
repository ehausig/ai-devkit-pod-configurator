---
description: Initialize autonomous development project from PROMPT.md
---

# Initialize Autonomous Project

Start a new project using the Team Topologies-based autonomous development system by reading requirements from `~/workspace/PROMPT.md`.

## Process

When invoked, I will:

1. **Check for PROMPT.md**:
   - Look for `~/workspace/PROMPT.md`
   - If not found, instruct user to create it
   - Read the contents as project requirements

2. **Initialize the Kanban system**:
   - Reset card counter to 0
   - Create JOURNAL.md if it doesn't exist

3. **Create initial project state**:
   - Log PROJECT_INIT event
   - Log USER_REQUEST with brief summary
   - Create initial Kanban cards based on requirements

4. **Start orchestration** as Product Manager (main thread)

## CRITICAL: Product Manager Role

You (the main Claude Code thread) ARE the Product Manager. You will:
- Orchestrate the entire development process
- Manage Kanban cards and state transitions
- Delegate work to specialized team members
- Track progress in JOURNAL.md

You are NOT a subagent - you run the orchestration directly.

## Usage Flow

1. User creates `~/workspace/PROMPT.md`:
   ```markdown
   # Project: [Name]
   
   [Detailed requirements and specifications]
   ```

2. User runs: `/init-autonomous`

3. System initializes and you begin orchestrating as Product Manager

## File Check

If PROMPT.md doesn't exist:
```
No PROMPT.md found. Please create ~/workspace/PROMPT.md with your project requirements:

cat > ~/workspace/PROMPT.md << 'EOF'
# Project: Your Project Name

Describe what you want to build...

## Requirements
- Feature 1
- Feature 2

## Technical Constraints
- Language preference
- Performance needs
EOF

Then run /init-autonomous again.
```

## Initialization Steps

```bash
# Reset card counter
echo "0" > /tmp/ai-devkit-card-counter

# Initialize project
journal-log.sh PROJECT_INIT "PM" "Starting project from PROMPT.md"

# Log user request (keep it brief - reference PROMPT.md)
journal-log.sh USER_REQUEST "PM" "See PROMPT.md for full requirements"

# Create initial cards based on requirements analysis
# Example:
CARD_ID=$(generate-card-id.sh)
journal-log.sh CARD_CREATED "PM" "CARD-$CARD_ID | Setup development environment | BACKLOG"

CARD_ID=$(generate-card-id.sh)
journal-log.sh CARD_CREATED "PM" "CARD-$CARD_ID | Design API specification | BACKLOG"

# Continue creating cards for identified work items...
```

## Orchestration Pattern

After initialization, follow this pattern:

1. **Review Kanban board state**
2. **Move cards through states**:
   - BACKLOG → BREAKDOWN_STARTED (assign to specialist)
   - BREAKDOWN_ENDED → IN_PROGRESS_STARTED (assign to developer)
   - IN_PROGRESS_ENDED → VALIDATION_STARTED (assign to QA)
   - VALIDATION_ENDED → DONE
3. **Delegate to appropriate team member**
4. **Process results and update cards**
5. **Continue until all cards are DONE**

## Benefits

- Clear requirements before starting
- Deterministic orchestration
- Full visibility into progress
- Team Topologies-based organization
- No reliance on hooks

The system uses explicit orchestration with the Product Manager (you) maintaining control of the development flow.
