# Persona Protocols

This directory contains the protocol documentation for each persona in the autonomous development system. These protocols guide Claude Code's behavior when executing each persona's commands.

## Overview

Each persona has specialized responsibilities in the software development lifecycle:

- **ARCHITECT**: System design and technical planning
- **DEVELOPER**: Implementation and coding
- **QA**: Testing and quality assurance  
- **REVIEWER**: Code review and approval
- **MERGER**: Integration and release management

## Protocol Structure

Each protocol document includes:

1. **Role Definition**: The persona's primary purpose
2. **Responsibilities**: Specific tasks the persona handles
3. **Journal Requirements**: How to log activities
4. **Handoff Criteria**: When to pass work to the next persona
5. **Decision Framework**: How to make technical choices

## Workflow

The typical workflow is linear but supports back-handoffs:

```
ARCHITECT → DEVELOPER → QA → REVIEWER → MERGER
             ↑          ↑        ↑
             └──────────┴────────┘
           (for fixes and changes)
```

## Usage

These protocols are reference documentation for the Claude Code commands. When a persona command is executed (e.g., `/architect`), Claude follows the corresponding protocol to:

1. Read assigned work from the journal
2. Execute tasks according to the protocol
3. Make and log decisions
4. Create required deliverables
5. Hand off to the next appropriate persona

## Key Principles

- **Event-Driven**: All work is tracked through journal events
- **Transparent**: All decisions are logged with rationale
- **Quality-Focused**: Each persona ensures their domain's quality
- **Collaborative**: Clear handoffs with specific tasks
- **Autonomous**: Personas work independently once activated

## Files

- `ARCHITECT-PROTOCOL.md` - System design and planning
- `DEVELOPER-PROTOCOL.md` - Implementation with TDD
- `QA-PROTOCOL.md` - Comprehensive testing
- `REVIEWER-PROTOCOL.md` - Code quality review
- `MERGER-PROTOCOL.md` - Integration and release
