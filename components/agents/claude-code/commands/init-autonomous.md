---
description: Initialize autonomous development project from PROMPT.md
---

# Initialize Autonomous Project

Start a new project using the autonomous sub agent development system by reading requirements from `~/workspace/PROMPT.md`.

## Process

When invoked, I will:

1. **Check for PROMPT.md**:
   - Look for `~/workspace/PROMPT.md`
   - If not found, instruct user to create it
   - Read the contents as project requirements

2. **Parse requirements** to determine:
   - Project type and complexity
   - Starting agent (product-manager for analysis, architect if very specific)

3. **Create the journal** at `~/workspace/JOURNAL.md` with:
   - PROJECT_INIT event
   - USER_REQUEST with full prompt content
   - WORK_ASSIGNED for the first agent
   - NEXT_AGENT directive

4. **Start autonomous flow** by instructing delegation

## Usage Flow

1. User creates `~/workspace/PROMPT.md`:
   ```markdown
   # Project: [Name]
   
   [Detailed requirements and specifications]
   ```

2. User runs: `/init-autonomous`

3. System reads PROMPT.md and begins autonomous development

## File Check

If PROMPT.md doesn't exist:
```
No PROMPT.md found. Please create ~/workspace/PROMPT.md with your project requirements:

cat > ~/workspace/PROMPT.md << 'EOF'
# Project: Your Project Name

Describe what you want to build...

## Requirements
- Feature 1
- Feature 2

## Technical Constraints
- Language preference
- Performance needs
EOF

Then run /init-autonomous again.
```

## Journal Initialization

Example journal creation:
```
2024-01-20T10:00:00Z | PROJECT_INIT | Starting project from PROMPT.md
2024-01-20T10:00:01Z | USER_REQUEST | [Full content from PROMPT.md]
2024-01-20T10:00:02Z | WORK_ASSIGNED | PRODUCT_MANAGER | Analyze requirements from PROMPT.md
2024-01-20T10:00:03Z | NEXT_AGENT | system | product-manager | Requirements analysis needed
```

## Benefits

- Clear requirements before starting
- Reproducible development cycles
- No ambiguity about project scope
- Easy to iterate on requirements
- Can version control PROMPT.md

The system will read PROMPT.md and begin the autonomous development cycle with clear, documented requirements.
