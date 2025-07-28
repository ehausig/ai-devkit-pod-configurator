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

3. **Create the journal** at `~/workspace/JOURNAL.md` using journal-log.sh:
   - Use `journal-log.sh PROJECT_INIT system "Starting project from PROMPT.md"`
   - Use `journal-log.sh USER_REQUEST system "[Brief summary of requirements]"`
   - Use `journal-log.sh WORK_ASSIGNED system "PRODUCT_MANAGER | Analyze requirements"`
   - Use `journal-log.sh NEXT_AGENT system "product-manager | Requirements analysis needed"`

4. **Start autonomous flow** by instructing delegation

## CRITICAL: Journal Creation

NEVER use echo or Write to create journal entries. ALWAYS use the journal-log.sh command which is available in PATH:
```bash
journal-log.sh EVENT_TYPE ACTOR "DESCRIPTION"
```

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

Use journal-log.sh commands to create entries:
```bash
# Initialize project
journal-log.sh PROJECT_INIT system "Starting project from PROMPT.md"

# Log user request (keep it brief - reference PROMPT.md instead of duplicating)
journal-log.sh USER_REQUEST system "See PROMPT.md for full requirements"

# Assign first work
journal-log.sh WORK_ASSIGNED system "PRODUCT_MANAGER | Analyze requirements from PROMPT.md"

# Create handoff
journal-log.sh NEXT_AGENT system "product-manager | Requirements analysis needed"
```

## Benefits

- Clear requirements before starting
- Reproducible development cycles
- No ambiguity about project scope
- Easy to iterate on requirements
- Can version control PROMPT.md

The system will read PROMPT.md and begin the autonomous development cycle with clear, documented requirements.
