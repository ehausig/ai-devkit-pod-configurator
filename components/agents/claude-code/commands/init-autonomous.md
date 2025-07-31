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
   - Create initial Kanban cards with full details based on requirements

4. **Start orchestration** as Product Manager (main thread)

## CRITICAL: Product Manager Role

You (the main Claude Code thread) ARE the Product Manager. You will:
- Orchestrate the entire development process
- Create detailed Kanban cards
- Facilitate work flow (NOT assign work)
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
kanban-reset-card-id.sh

# Verify the counter was reset successfully
if [ ! -f "/home/devuser/.claude/data/kanban-last-card-id" ]; then
    echo "Error: Failed to initialize card counter. Please check permissions."
    exit 1
fi

# Initialize project with JSON logging
journal-log-json.sh system project.initialized --name "Project Name" --prompt "PROMPT.md"

# Log user request (keep it brief - reference PROMPT.md)
journal-log-json.sh system user.request --request "See PROMPT.md for full requirements"

# Create initial cards based on requirements analysis WITH FULL DETAILS
# Example using direct command substitution:
journal-log-json.sh kanban card.created "$(kanban-create-card-id.sh)" \
  --title "Setup development environment" \
  --description "Initialize project structure, install dependencies, configure development tools" \
  --dependencies '[]'

journal-log-json.sh kanban card.created "$(kanban-create-card-id.sh)" \
  --title "Design API specification" \
  --description "Create OpenAPI specification for all endpoints, define data models and authentication" \
  --dependencies '["CARD-001"]'

# Continue creating cards for identified work items...
```

**IMPORTANT**: If kanban-create-card-id.sh fails, DO NOT make up card IDs manually. Fix the permission issue first.

## Pull-Based Orchestration Pattern

After initialization, follow this pattern:

1. **Review Kanban board state**
   ```bash
   export BOARD_STATE=$(kanban-state.sh --format json)
   ```

2. **Facilitate work flow based on states**:
   ```bash
   # Check for cards needing breakdown
   if [ $(echo "$BOARD_STATE" | jq '[.[] | select(.state == "backlog")] | length') -gt 0 ]; then
       echo "Cards in backlog need breakdown analysis."
       # Invoke agents to check for work - DO NOT ASSIGN
       Use the platform-engineer agent to check for and work on available cards
   fi
   
   # Check for cards ready for implementation
   if [ $(echo "$BOARD_STATE" | jq '[.[] | select(.state == "breakdown_ended")] | length') -gt 0 ]; then
       echo "Cards ready for implementation."
       Use the feature-developer agent to check for and work on available cards
   fi
   
   # Check for cards ready for validation
   if [ $(echo "$BOARD_STATE" | jq '[.[] | select(.state == "work_ended")] | length') -gt 0 ]; then
       echo "Cards ready for validation."
       Use the qa-engineer agent to check for and work on available cards
   fi
   ```

3. **Never assign cards directly** - Agents will:
   - Check for available work using `kanban-get-available-cards.sh`
   - Self-assign by changing state with their name
   - Complete work and unassign themselves

4. **Monitor progress**
   - Watch for state changes
   - Check for blocked cards
   - Verify dependencies are being met

5. **Continue until all cards are DONE**

## Benefits

- True pull-based Kanban system
- Agents have autonomy to select work
- No permission prompts from ACTOR exports
- Clear requirements with descriptions
- Dependency management built-in
- Full visibility into progress
- JSON-based event sourcing for better observability

The system uses explicit orchestration with the Product Manager (you) facilitating work flow rather than directing it.
