# LLM Context Documentation

This directory contains documentation specifically designed to provide context and state information to Large Language Models (LLMs) like Claude when working with the AI DevKit Pod Configurator project.

## Files

### State Tracking
- **CURRENT_STATE.md** - Current project state, active branch, recent fixes, and test status
- **JOURNAL.md** - Development journal documenting architectural decisions and milestones

### Session Bootstrap
- **SESSION_BOOTSTRAP.md** - High-level description of build-and-deploy.sh to bootstrap LLM sessions without full implementation details

## Purpose

These files serve several purposes:

1. **Contextual Awareness** - Provide LLMs with project history and current state
2. **Decision Tracking** - Document why certain architectural choices were made
3. **State Continuity** - Allow LLMs to understand project status across sessions
4. **Interface Documentation** - Describe key scripts without full implementation

## Usage

When working with an LLM on this project:
1. The LLM should read CURRENT_STATE.md to understand the current project status
2. Reference JOURNAL.md for historical context on architectural decisions
3. Use SESSION_BOOTSTRAP.md to understand key script interfaces without needing full source code

Note: User-facing prompt templates are in the `/prompts` directory at the root level

## Maintenance

- **CURRENT_STATE.md** - Update after significant changes or test completions
- **JOURNAL.md** - Add entries for major architectural decisions or milestones
- **SESSION_BOOTSTRAP.md** - Update when build-and-deploy.sh interfaces change significantly