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

## Implementation Note

Make it VERY clear to the user that we're in requirements gathering mode:

"I'll help you create a project specification through interactive requirements gathering. 

**Important**: We're not building anything yet - just defining what you want. The actual implementation will happen after you run /init-autonomous.

Let me delegate to the requirements analyst who will ask you some questions about your project."

## Workflow

1. User runs `/create-prompt`
2. Clear context is set about requirements gathering
3. Requirements analyst asks questions
4. PROMPT.md is created
5. User runs `/init-autonomous` to start development
