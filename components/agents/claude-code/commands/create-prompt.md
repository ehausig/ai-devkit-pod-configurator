---
description: Interactive requirements gathering to create PROMPT.md
---

# Create Project Prompt

Interactively gather requirements and create a well-structured PROMPT.md file for autonomous development.

## Process

When invoked, I will:

1. **Set context clearly**:
   - Explain we're gathering requirements, NOT building yet
   - Clarify that implementation happens after `/init-autonomous`

2. **Delegate to requirements analyst**:
   - Invoke the requirements-analyst agent
   - Let it handle interactive gathering
   - It will create ~/workspace/PROMPT.md

3. **Provide next steps**:
   - Confirm PROMPT.md was created
   - Instruct user to run `/init-autonomous`
   - DO NOT start any development work

## Implementation Note

Make it VERY clear to the user that we're in requirements gathering mode:

"I'll help you create a project specification through interactive requirements gathering. 

**Important**: We're not building anything yet - just defining what you want. The actual implementation will happen after you run /init-autonomous.

Let me delegate to the requirements analyst who will ask you some questions about your project."

## CRITICAL Instructions

After the requirements analyst completes:
- **DO NOT** start any development work
- **DO NOT** call /init-autonomous automatically
- **DO NOT** invoke any other agents
- **DO NOT** create Kanban cards
- **DO NOT** write to JOURNAL.md
- Simply confirm PROMPT.md was created and remind the user to run /init-autonomous

## Workflow

1. User runs `/create-prompt`
2. Clear context is set about requirements gathering
3. Requirements analyst asks questions
4. PROMPT.md is created
5. Return control to user with instruction to run `/init-autonomous`
6. STOP - do nothing else

## Example Response After Completion

"Perfect! I've created ~/workspace/PROMPT.md with your project requirements.

To start the autonomous development process, please run:

```
/init-autonomous
```

This will read your requirements and begin building your project."

**DO NOT PROCEED WITH DEVELOPMENT AFTER THIS MESSAGE**
