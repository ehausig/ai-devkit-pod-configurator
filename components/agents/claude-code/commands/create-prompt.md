---
description: Interactive requirements gathering to create PROMPT.md
---

# Create Project Prompt

Interactively gather requirements and create a well-structured PROMPT.md file for autonomous development.

## Process

When invoked, I will:

1. **Set context clearly**:
   - Explain we're gathering requirements
   - This is just for creating a project specification

2. **Delegate to requirements analyst**:
   - Invoke the requirements-analyst agent
   - Let it handle interactive gathering
   - It will create ~/workspace/PROMPT.md

3. **Confirm completion**:
   - Confirm PROMPT.md was created
   - DO NOT start any development work

## Implementation Note

Make it clear to the user that we're in requirements gathering mode:

"I'll help you create a project specification through interactive requirements gathering. Let me delegate to the requirements analyst who will ask you some questions about your project."

## CRITICAL Instructions

After the requirements analyst completes:
- **DO NOT** start any development work
- **DO NOT** invoke any other agents
- **DO NOT** create Kanban cards
- **DO NOT** write to JOURNAL.md
- Simply confirm PROMPT.md was created

## Workflow

1. User runs this command
2. Clear context is set about requirements gathering
3. Requirements analyst asks questions
4. PROMPT.md is created
5. Return control to user
6. STOP - do nothing else

## Example Response After Completion

"Perfect! I've created ~/workspace/PROMPT.md with your project requirements."

**DO NOT PROCEED AFTER THIS MESSAGE**
