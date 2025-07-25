# Claude Code - Autonomous Development System

An AI-powered coding assistant with an autonomous event-driven development system that manages the complete software development lifecycle through specialized personas.

## Overview

Claude Code provides an intelligent development environment where AI personas collaborate to design, implement, test, review, and deploy software projects autonomously. The system uses event sourcing with a persistent journal to maintain context and coordinate work between personas.

## Features

- **Autonomous Development**: Once initiated, the system completes the entire development cycle
- **Specialized Personas**: ARCHITECT, DEVELOPER, QA, REVIEWER, and MERGER each handle their domain
- **Event-Driven Architecture**: All work is tracked through events in a persistent journal
- **Context Preservation**: The journal maintains state across Claude Code sessions
- **Flexible Workflow**: Supports non-linear development with handoffs back for fixes
- **Transparent Process**: All decisions and work are logged for complete visibility

## Quick Start

1. Start Claude Code:
   ```bash
   claude
   ```

2. Describe your project:
   ```
   Please initiate the architect persona and create a hello world project in Python
   ```

3. Claude will use `/init-project` to start the autonomous development process

4. Monitor progress:
   ```
   /show-journal
   /persona-status
   ```

## Architecture

### Component Structure
```
claude-code/
├── commands/           # Claude Code slash commands
├── hooks/             # Orchestration hook
├── personas/          # Persona protocol documentation
├── claude-settings.json.template
└── user-CLAUDE.md
```

### Event Flow
```
User Request
    ↓
/init-project → WORK_ASSIGNED → ARCHITECT
    ↓
ARCHITECT completes → HANDOFF → DEVELOPER
    ↓
DEVELOPER completes → HANDOFF → QA
    ↓
QA passes → HANDOFF → REVIEWER
    ↓
REVIEWER approves → HANDOFF → MERGER
    ↓
MERGER completes → CYCLE_COMPLETE
```

### Journal Structure
```
2024-01-15T10:00:00Z | WORK_ASSIGNED | ARCHITECT | Design system
2024-01-15T10:05:00Z | DECISION | ARCHITECT | Using Flask framework
2024-01-15T10:10:00Z | FILE_CREATED | ARCHITECT | ARCHITECTURE.md
2024-01-15T10:15:00Z | HANDOFF | ARCHITECT->DEVELOPER | 5 tasks
```

## Commands

- `/init-project` - Parse request and start development
- `/architect` - System design persona
- `/developer` - Implementation persona
- `/qa` - Testing persona
- `/reviewer` - Code review persona
- `/merger` - Integration persona
- `/event-emit` - Add events to journal
- `/event-query` - Query journal events
- `/show-journal` - Display journal with formatting
- `/persona-status` - Show all persona states

## Personas

### ARCHITECT
- Creates system design and architecture
- Makes technology decisions
- Defines data models and APIs
- Creates testing strategy

### DEVELOPER
- Implements code using TDD
- Ensures 80% test coverage
- Creates documentation
- Handles review fixes

### QA
- Runs comprehensive tests
- Uses real services (no mocks)
- Tests user workflows
- Documents issues

### REVIEWER
- Reviews code quality
- Checks architecture compliance
- Validates security practices
- Provides feedback

### MERGER
- Integrates approved changes
- Updates documentation
- Creates releases
- Completes cycle

## Configuration

The system is configured through `claude-settings.json.template` which includes:
- Orchestration hook configuration
- File permissions
- Environment variables

## Development Workflow

1. **Project Initialization**: User describes project → `/init-project` parses and starts
2. **Architecture Phase**: ARCHITECT designs system and creates documentation
3. **Implementation Phase**: DEVELOPER implements with TDD approach
4. **Testing Phase**: QA performs comprehensive testing
5. **Review Phase**: REVIEWER ensures quality and compliance
6. **Integration Phase**: MERGER completes the cycle

## Monitoring

Track development progress with:
- `/show-journal` - Recent events with emoji indicators
- `/persona-status` - Current state of each persona
- `/event-query DEVELOPER WORK_ASSIGNED` - Specific queries

## Notes

- The system runs autonomously after initialization
- All work is event-driven through the journal
- Context is preserved across sessions
- Personas can hand work back (e.g., for fixes)
- The orchestration hook ensures continuous progress
