# Claude Code Agents

This directory contains the Team Topologies-based agent definitions for the Claude Code autonomous development system.

## Overview

Each `.md` file in this directory defines a specialized AI agent that can be delegated specific tasks during the development process. Agents are organized according to Team Topologies principles.

## Team Structure

### Stream-Aligned Team
Focus on delivering features end-to-end:
- `feature-developer.md` - Implements features and business logic
- `qa-engineer.md` - Tests and validates implementations

### Platform Team
Provide foundational capabilities:
- `platform-engineer.md` - Infrastructure, CI/CD, deployment
- `database-engineer.md` - Data models and persistence

### Enabling Team
Help other teams overcome obstacles:
- `api-designer.md` - API specifications and contracts
- `security-specialist.md` - Security reviews and hardening
- `performance-engineer.md` - Performance optimization
- `solution-architect.md` - High-level system design
- `cloud-architect.md` - Cloud infrastructure design
- `data-architect.md` - Enterprise data architecture

### Complicated Subsystem Team
Handle complex technical domains:
- `integration-specialist.md` - Third-party integrations
- `algorithm-developer.md` - Complex algorithms
- `requirements-analyst.md` - Interactive requirements gathering

## Agent File Format

Each agent is a Markdown file with YAML frontmatter:

```markdown
---
name: agent-name
description: When this agent should be used
tools: Read, Write, Edit, Bash, Glob  # Optional, inherits all if omitted
---

Agent's system prompt and instructions...
```

## How Agents Work

1. **Product Manager** (main thread) orchestrates the development process
2. Agents are invoked through delegation: "Use the api-designer agent to..."
3. Each agent operates in its own context window
4. Work is tracked through Kanban cards in JOURNAL.md
5. Agents update card states and hand off to next agent

## Creating New Agents

To add a new agent:

1. Choose the appropriate team based on the agent's role
2. Create a `.md` file with descriptive name
3. Add frontmatter with name, description, and optional tools
4. Write clear system prompt explaining:
   - The agent's role and expertise
   - How to handle assigned cards
   - Work process and outputs
   - Handoff procedures

## Best Practices

- Keep agents focused on a single domain
- Use clear, action-oriented descriptions
- Include example workflows in prompts
- Define clear handoff points
- Log all significant actions to JOURNAL.md

## Integration with Autonomous System

Agents are automatically:
- Copied to `~/.claude/agents/` during build
- Available for delegation by Product Manager
- Integrated with the Kanban card system
- Part of the deterministic workflow

See the main [Claude Code README](../README.md) for more details on the autonomous development system.
