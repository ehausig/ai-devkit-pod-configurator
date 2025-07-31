---
description: Interactive requirements gathering to create PROMPT.md
---

# Create Project Prompt

Interactively gather requirements and create a well-structured PROMPT.md file for autonomous development.

## CRITICAL: This is ONLY for Requirements Gathering

**This command does NOT build anything. It ONLY creates PROMPT.md.**

When the user provides project details after running this command:
- **DO NOT** start building
- **DO NOT** create any code files
- **DO NOT** run any development commands
- **DO NOT** set up environments
- **ONLY** save their requirements to PROMPT.md

## Process

When invoked, I will:

1. **Set context clearly**:
   - Explain we're ONLY gathering requirements
   - We are NOT building anything yet
   - This ONLY creates a specification file

2. **Delegate to requirements analyst**:
   - Invoke the requirements-analyst agent
   - Let it handle interactive gathering
   - It will create ~/workspace/PROMPT.md

3. **Stop completely**:
   - Confirm PROMPT.md was created
   - Do NOT proceed with any development
   - Return control to the user

## Implementation Note

Make it EXTREMELY clear to the user that we're in requirements gathering mode:

"I'll help you create a project specification through interactive requirements gathering. 

**IMPORTANT**: This command ONLY creates a requirements file (PROMPT.md). It does NOT build anything. After I gather your requirements, you'll need to run a separate command if you want to start development.

Let me delegate to the requirements analyst who will ask you some questions about your project."

## CRITICAL Instructions

**If the user provides project details during requirements gathering:**
- Save them to PROMPT.md
- Thank them for the information
- Confirm the file was created
- **STOP COMPLETELY**

**DO NOT:**
- Start any development work
- Create project files
- Set up environments
- Install dependencies
- Write any code
- Create Kanban cards
- Write to JOURNAL.md

## Workflow

1. User runs `/create-prompt`
2. Explain this is ONLY for requirements
3. Requirements analyst asks questions
4. User provides project details
5. Save to PROMPT.md
6. Confirm file created
7. **STOP - do nothing else**

## Example Response After Completion

"Perfect! I've created ~/workspace/PROMPT.md with your project requirements.

Your requirements have been saved. No development work has been started."

**THE COMMAND ENDS HERE. DO NOT PROCEED.**
