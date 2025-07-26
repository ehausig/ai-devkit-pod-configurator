---
description: Interactive requirements gathering to create PROMPT.md
---

# Create Project Prompt

Interactively gather requirements and create a well-structured PROMPT.md file for autonomous development.

## Process

When invoked, I will:

1. **Check for existing PROMPT.md**:
   - If exists, ask if user wants to overwrite
   - If not, proceed with creation

2. **Delegate to requirements analyst**:
   - Invoke the requirements-analyst agent
   - Let it handle interactive gathering
   - It will create ~/workspace/PROMPT.md

3. **Provide next steps**:
   - Confirm PROMPT.md was created
   - Instruct user to run `/init-autonomous`

## Usage

```
/create-prompt
```

## Workflow

1. User runs `/create-prompt`
2. Requirements analyst asks questions
3. PROMPT.md is created
4. User runs `/init-autonomous` to start development

## Note

This command is optional. Experienced users can create PROMPT.md manually and skip directly to `/init-autonomous`.

## Implementation Note

The command should immediately delegate to requirements-analyst without checking for PROMPT.md first. The agent will handle file existence checks.

## Example Response

Simply: "I'll help you create a project specification through interactive requirements gathering."

Then delegate immediately to requirements-analyst.
