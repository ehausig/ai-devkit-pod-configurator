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
   - Log PROJECT_INIT event in JSON format
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

# Initialize project with JSON logging
journal-log-json.sh system project.initialized --name "Project Name" --prompt "PROMPT.md"

# Log user request (keep it brief - reference PROMPT.md)
journal-log-json.sh system user.request --request "See PROMPT.md for full requirements"

# Create initial cards based on requirements analysis
# Example using direct command substitution:
journal-log-json.sh kanban card.created "$(generate-card-id.sh)" --title "Setup development environment"

journal-log-json.sh kanban card.created "$(generate-card-id.sh)" --title "Design API specification"

# Continue creating cards for identified work items...
```

## Orchestration Pattern

After initialization, follow this pattern:

1. **Review Kanban board state**
   ```bash
   export BOARD_STATE=$(kanban-state.sh --format json)
   ```

2. **Move cards through states**:
   - BACKLOG → BREAKDOWN_STARTED (assign to specialist)
   - BREAKDOWN_ENDED → WORK_STARTED (assign to developer)
   - WORK_ENDED → VALIDATION_STARTED (assign to QA)
   - VALIDATION_ENDED → DONE

3. **Delegate to appropriate team member**
   ```bash
   journal-log-json.sh kanban card.breakdown.started "$CARD_ID"
   journal-log-json.sh kanban card.assigned "$CARD_ID" --to "api-designer"
   ```

4. **Process results and update cards**
5. **Continue until all cards are DONE**

## Benefits

- Clear requirements before starting
- Deterministic orchestration
- Full visibility into progress
- Team Topologies-based organization
- No reliance on hooks
- JSON-based event sourcing for better observability

The system uses explicit orchestration with the Product Manager (you) maintaining control of the development flow.
