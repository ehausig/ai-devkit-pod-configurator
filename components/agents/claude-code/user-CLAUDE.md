# Autonomous Development System

## Quick Start

Simply tell me what you want to build:
- "Create a REST API for a todo list"
- "Build a web scraper in Node.js"
- "Develop a CLI tool in Rust"
- "Create a real-time chat application"

Then use `/init-autonomous` to start the autonomous development process. The system will automatically progress through specialized agents to design, implement, test, review, and release your project.

## How It Works

This system uses **autonomous sub agents** where specialized personas (PRODUCT_MANAGER, ARCHITECT, DEVELOPER, QA, REVIEWER, MERGER) collaborate through a persistent journal. Each agent:

1. **Reads** the journal to understand assigned work
2. **Performs** specialized tasks in isolation
3. **Records** decisions and progress
4. **Writes** NEXT_AGENT directive for handoffs
5. **Delegates** to the next appropriate agent

The Stop hook ensures continuous autonomous execution by reading NEXT_AGENT directives and prompting the next delegation.

## Available Commands

### Project Initialization
- `/init-autonomous` - Parse your request and start autonomous development

### Monitoring
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

## Important Notes

- The system runs **autonomously** after initialization
- All work is tracked through **events** in the journal
- Each agent makes **decisions** based on specialized expertise
- The journal provides **complete visibility** into progress
- Non-linear workflows are supported for iterations
- The cycle completes when MERGER logs `CYCLE_COMPLETE`

---

*Start by describing your project, then use `/init-autonomous` to begin the autonomous development process!*
