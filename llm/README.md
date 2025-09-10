# LLM Context Documentation

This directory contains documentation specifically designed to provide context and maintain state for Large Language Models (LLMs) like Claude when working with the AI DevKit Pod Configurator project.

## Files

### 🚀 BOOTSTRAP_SESSION.md
**Start here for new sessions**
- Instructions for session initialization
- Project structure overview
- How to use the LLM context files
- Common tasks and best practices

### 📐 PRINCIPLES.md
**Core principles and architectural decisions**
- Distilled lessons from development
- Architecture Decision Records (ADRs)
- Anti-patterns to avoid
- Governs LLM behavior and decision-making

### 📊 CURRENT_STATE.md
**Current project state and progress**
- Recent changes and fixes
- Test status and results
- Known issues and next actions
- Updated frequently during development

## Purpose

These files work together to:

1. **Orient New Sessions** - BOOTSTRAP_SESSION.md helps LLMs understand the project quickly
2. **Maintain Continuity** - CURRENT_STATE.md preserves context across sessions
3. **Guide Decisions** - PRINCIPLES.md ensures consistent architectural choices
4. **Prevent Regression** - Documented anti-patterns prevent repeating mistakes

## Usage

### Starting a New Session
1. Read `BOOTSTRAP_SESSION.md` first for orientation
2. Read `PRINCIPLES.md` to understand the rules
3. Read `CURRENT_STATE.md` to see current progress
4. Begin work based on "Next Actions" in CURRENT_STATE.md

### During Development
- Consult `PRINCIPLES.md` when making architectural decisions
- Update `CURRENT_STATE.md` after significant changes
- Refer to `BOOTSTRAP_SESSION.md` for project structure

### Before Ending Session
- Update `CURRENT_STATE.md` with:
  - Work completed
  - Issues discovered
  - Test results
  - Next actions

## Maintenance

### BOOTSTRAP_SESSION.md
- Update rarely, only for major structural changes
- Keep focused on orientation and instructions
- Should remain stable across sessions

### PRINCIPLES.md
- Add new principles when discovering patterns from bugs
- Document new architectural decisions
- Never remove principles without careful consideration

### CURRENT_STATE.md
- Update frequently during active development
- Keep "Next Actions" current
- Record all significant changes and test results
- Clear out completed items periodically

## Key Benefits

- **Context Preservation** - Critical information survives context window compaction
- **Faster Onboarding** - New sessions productive immediately
- **Consistent Behavior** - Principles ensure architectural consistency
- **Reduced Errors** - Anti-patterns prevent known mistakes
- **Clear Direction** - Current state provides immediate next steps

## Important Notes

- These files are for LLM consumption, not end-user documentation
- Keep content concise but comprehensive
- Focus on actionable information
- Maintain accuracy - outdated context is worse than no context