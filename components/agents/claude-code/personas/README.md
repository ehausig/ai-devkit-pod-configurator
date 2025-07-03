# Multi-Persona Development System

## Overview

The multi-persona system enables Claude Code to operate with different specialized roles during software development, simulating how a real development team works. Each persona has specific responsibilities, protocols, and handoff procedures.

## Workspace Organization

To prevent conflicts and maintain clean separation of concerns, each persona uses specific directories:

```
~/workspace/
├── hello-world/              # Main project (ARCHITECT, DEVELOPER, MERGER)
├── reviewer/                 # Review workspace
│   └── hello-world-review/   # Cloned for code review
└── qa/                       # QA isolation workspace (optional)
    └── hello-world-test/     # Cloned for isolated testing
```

### Directory Usage by Persona:
- **ARCHITECT**: Creates initial project in `~/workspace/[project-name]`
- **DEVELOPER**: Works in `~/workspace/[project-name]`
- **QA**: Tests in main project OR clones to `~/workspace/qa/` for isolation
- **REVIEWER**: Always clones to `~/workspace/reviewer/` for clean review
- **MERGER**: Works in main `~/workspace/[project-name]` for final integration

## Available Personas

### ARCHITECT
- **Role**: System design and technical planning
- **Responsibilities**: Architecture, technology selection, API design, documentation
- **Creates**: ARCHITECTURE.md, API_DESIGN.md, DATA_MODELS.md, TESTING_STRATEGY.md
- **Hands off to**: DEVELOPER

### DEVELOPER  
- **Role**: Implementation and coding
- **Responsibilities**: TDD implementation, feature branches, code quality
- **Creates**: Working code, tests, pull requests
- **Hands off to**: QA

### QA
- **Role**: Testing and quality assurance
- **Responsibilities**: Test execution, bug finding, real service testing
- **Creates**: TEST_REPORT.md, bug reports
- **Hands off to**: REVIEWER (if passed) or DEVELOPER (if fixes needed)

### REVIEWER
- **Role**: Code review
- **Responsibilities**: Quality checks, architecture compliance, security review
- **Creates**: REVIEW_REPORT.md, PR comments
- **Hands off to**: MERGER (if approved) or DEVELOPER (if changes needed)

### MERGER
- **Role**: Integration and deployment
- **Responsibilities**: Merging PRs, releases, documentation updates
- **Creates**: MERGE_REPORT.md, release tags
- **Completes**: Development cycle

## Workflow

```
ARCHITECT → DEVELOPER → QA → REVIEWER → MERGER
    ↓                           ↑
    └───────────────────────────┘ (if changes needed)
```

## Journal-Based Memory

Each persona logs activities to `~/workspace/JOURNAL.md` with structured tags. The journal serves as persistent memory that survives context switches and session restarts.

### Logging Commands

Use the `journal-log` command to avoid echo approval prompts:

```bash
# Log architectural decision
journal-log "ARCHITECT:DECISION" "Chose FastAPI for REST API framework"

# Log development issue
journal-log "DEVELOPER:ISSUE" "Circular import in models.py"

# Log test result
journal-log "QA:PASSED" "All integration tests passing"
```

### Journal Tags

- `[PERSONA:INIT]` - Initialization
- `[PERSONA:CONTEXT]` - Current context
- `[PERSONA:MEMORY]` - Persistent information
- `[PERSONA:DECISION]` - Important decisions
- `[PERSONA:HANDOFF]` - Work transitions
- `[PERSONA:ISSUE]` - Problems found
- `[PERSONA:RESOLVED]` - Solutions
- `[PERSONA:FEEDBACK]` - Review feedback

## Usage

### Switching Personas

```bash
# Initialize a persona
/home/devuser/.claude/personas/[persona]/[persona]-init.sh

# Example: Switch to developer
/home/devuser/.claude/personas/developer/developer-init.sh
```

When you run an initialization script:
1. The persona switch is logged
2. Previous context is loaded from journal
3. Pending handoffs are shown
4. **The full persona protocol is displayed inline**
5. You should follow the displayed protocol

### Handoffs

```bash
# Complete work and hand off to next persona
/home/devuser/.claude/personas/[persona]/[persona]-handoff.sh

# Example: Developer hands off to QA
/home/devuser/.claude/personas/developer/developer-handoff.sh
```

Handoff scripts:
1. Validate completion criteria
2. Create handoff documents (e.g., HANDOFF_TO_QA.md)
3. Log the transition
4. Show next steps

### Context Recovery

If context is lost, personas can reconstruct their state:

```bash
# Show current context
grep "\[DEVELOPER:" ~/workspace/JOURNAL.md | tail -20

# Show persistent memories
grep "PERSONA:MEMORY" ~/workspace/JOURNAL.md

# Show pending handoffs
grep "HANDOFF.*DEVELOPER" ~/workspace/JOURNAL.md
```

## Benefits

1. **Separation of Concerns**: Each persona focuses on their domain
2. **Quality Gates**: Issues caught earlier in the process
3. **Context Persistence**: Survives Claude Code session restarts
4. **Audit Trail**: Complete history of decisions and actions
5. **Team Simulation**: More realistic development workflow

## Example Project Flow

1. **ARCHITECT** designs a GraphQL API system
   ```bash
   journal-log "ARCHITECT:DECISION" "GraphQL with Apollo Server"
   journal-log "ARCHITECT:MEMORY" "Must support 10k concurrent users"
   ```

2. **DEVELOPER** creates `feat/backend-api` branch and implements with TDD
   ```bash
   git checkout -b feat/backend-api
   journal-log "DEVELOPER:CONTEXT" "Implementing user authentication"
   ```

3. **QA** tests against real running services, finds mock test issue
   ```bash
   journal-log "QA:ISSUE" "Integration tests using mocks instead of real backend"
   ```

4. **DEVELOPER** fixes the tests to use real backends
   ```bash
   journal-log "DEVELOPER:RESOLVED" "Updated tests to use real GraphQL endpoint"
   ```

5. **QA** re-tests and approves
   ```bash
   journal-log "QA:PASSED" "All integration tests now using real services"
   ```

6. **REVIEWER** checks code quality and architecture compliance
   ```bash
   journal-log "REVIEWER:APPROVED" "Code meets all standards"
   ```

7. **MERGER** integrates changes and creates release
   ```bash
   journal-log "MERGER:RELEASE" "v1.0.0 - Initial GraphQL API"
   ```

## Troubleshooting

### Permission Denied
If you get "Permission denied" when running persona scripts, ensure they're executable:
```bash
chmod +x ~/.claude/personas/*/*.sh
```

### Journal Not Found
The journal is created automatically, but if missing:
```bash
touch ~/workspace/JOURNAL.md
echo "# Development Journal" > ~/workspace/JOURNAL.md
```

### Context Not Loading
Check that hooks are properly installed:
```bash
ls -la ~/.claude/hooks/persona-manager.sh
ls -la ~/.claude/hooks/journal-context.sh
```

## Customization

Each persona's behavior is defined in:
- `[persona]/[PERSONA]-PROTOCOL.md` - Guidelines and responsibilities
- `[persona]/[persona]-init.sh` - Initialization script
- `[persona]/[persona]-handoff.sh` - Handoff script

Modify these files to adjust persona behavior for your team's workflow.
