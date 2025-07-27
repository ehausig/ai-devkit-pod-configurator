# Autonomous Development System

## CRITICAL: Agent Message Pass-Through

When a sub-agent provides a response:
- IF the response appears to be a question or statement for the user
- THEN display it verbatim without ANY interpretation
- NEVER prefix with "The [agent] is asking/saying..."
- NEVER convert first-person agent speech to third-person narrative
- NEVER summarize or paraphrase agent communications
- ALWAYS preserve the agent's exact tone and phrasing

Examples:
- WRONG: "The requirements analyst is now asking about your project type..."
- WRONG: "The developer agent says they've completed the implementation..."
- RIGHT: [Show exactly what the agent said without any wrapper text]

## CRITICAL: Agent Delegation Instructions

When using sub agent commands that delegate to agents:
- Let agents communicate naturally with users
- Show agent messages directly without interpretation
- Allow back-and-forth conversation between user and agent
- Treat agent responses as if they ARE the conversation, not data about a conversation

## Quick Start

### Option 1: Interactive Requirements (Easier)
1. **Run the requirements gathering command**:
   ```
   /create-prompt
   ```
   I'll ask you questions about your project and create PROMPT.md for you.

2. **Start autonomous development**:
   ```
   /init-autonomous
   ```

### Option 2: Direct Requirements (Faster)
1. **Create your requirements file** at `~/workspace/PROMPT.md`:
   ```markdown
   # Project: Todo Management API
   
   Create a REST API for managing todos with:
   - CRUD operations
   - Status filtering
   - PostgreSQL storage
   ```

2. **Run the initialization command**:
   ```
   /init-autonomous
   ```

Both approaches lead to the same autonomous development process.

## How It Works

This system uses **autonomous sub agents** where specialized personas (PRODUCT_MANAGER, ARCHITECT, DEVELOPER, QA, REVIEWER, MERGER) collaborate through a persistent journal. Each agent:

1. **Reads** the journal to understand assigned work
2. **Performs** specialized tasks in isolation
3. **Records** decisions and progress
4. **Writes** NEXT_AGENT directive for handoffs
5. **Delegates** to the next appropriate agent

The Stop hook ensures continuous autonomous execution by reading NEXT_AGENT directives and prompting the next delegation.

## Available Commands

### Commands
- `/create-prompt` - Interactive requirements gathering (creates PROMPT.md)
- `/init-autonomous` - Read requirements from ~/workspace/PROMPT.md and start development
- `/show-journal` - Display recent journal entries
- `/event-query [type]` - Query specific events from the journal

## Available Agents

1. **product-manager** - Requirements analysis and user stories
2. **architect** - System design and technical planning
3. **developer** - Implementation using TDD practices
4. **qa** - Comprehensive testing with real services
5. **reviewer** - Code review and quality assurance
6. **merger** - Integration and release management

## Journal Structure

The `~/workspace/JOURNAL.md` file tracks all development activities:

```
2024-01-15T10:00:00Z | PROJECT_INIT | Starting todo list API
2024-01-15T10:00:01Z | WORK_ASSIGNED | PRODUCT_MANAGER | Define requirements
2024-01-15T10:00:02Z | NEXT_AGENT | system | product-manager | Requirements needed
2024-01-15T10:15:00Z | DECISION | product-manager | RESTful API with CRUD operations
2024-01-15T10:30:00Z | WORK_ASSIGNED | ARCHITECT | Design system for todo API
2024-01-15T10:30:01Z | NEXT_AGENT | product-manager | architect | Requirements complete
```

## Autonomous Flow

The system automatically progresses through agents:
```
PRODUCT_MANAGER → ARCHITECT → DEVELOPER → QA → REVIEWER → MERGER
```

Non-linear flows are supported (e.g., REVIEWER → DEVELOPER for fixes).

## Key Features

- **Fully Autonomous**: Once started, requires no manual intervention
- **Context Isolation**: Each agent has its own context window
- **State Persistence**: Journal maintains continuity across agents
- **Flexible Workflow**: Supports iterative development cycles
- **Real Testing**: QA uses actual services, not mocks
- **Complete Visibility**: Journal provides full audit trail

## Sub Agent Guidelines

This system uses specialized sub agents for different phases of development. When these agents are invoked:

1. **Direct Communication** - Agents should communicate directly with users, not through intermediaries
2. **Natural Language** - Use first-person language ("I'll help you...") not third-person ("The agent will...")
3. **Seamless Handoffs** - Transitions between agents should feel natural
4. **Preserve Context** - Each agent reads the journal to maintain continuity

## Important Notes

- The system runs **autonomously** after initialization
- All work is tracked through **events** in the journal
- Each agent makes **decisions** based on specialized expertise
- The journal provides **complete visibility** into progress
- Non-linear workflows are supported for iterations
- The cycle completes when MERGER logs `CYCLE_COMPLETE`

---

*Create your project requirements in ~/workspace/PROMPT.md, then use `/init-autonomous` to begin the autonomous development process!*
