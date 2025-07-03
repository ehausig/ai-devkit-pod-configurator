# Multi-Persona Development System

## Overview

The multi-persona system enables Claude Code to operate with different specialized roles during software development, simulating how a real development team works. Each persona has specific responsibilities, protocols, and handoff procedures.

## Key Features

### Event-Driven Architecture
- **Journal as Event Store**: All work, decisions, and state changes are recorded as immutable events
- **Work Item Tracking**: Explicit `WORK:PENDING`, `WORK:STARTED`, `WORK:COMPLETED` states
- **Safety Mechanisms**: Prevents infinite loops through iteration counting and progress checking
- **Context Persistence**: Survives Claude Code session restarts and context switches

### Automated Workflow
- **Smart Handoffs**: Each persona validates completion before handing off
- **Work Item Generation**: Automatically creates specific tasks for the next persona
- **Progress Tracking**: Real-time monitoring of work completion
- **Error Recovery**: Built-in mechanisms for handling stuck states

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
- **Key Commands**:
  ```bash
  journal-log "ARCHITECT:DECISION" "Chose FastAPI for REST API"
  journal-log "ARCHITECT:MEMORY" "Must support 10k concurrent users"
  ```

### DEVELOPER  
- **Role**: Implementation and coding
- **Responsibilities**: TDD implementation, feature branches, code quality
- **Creates**: Working code, tests, pull requests
- **Hands off to**: QA
- **Key Commands**:
  ```bash
  journal-log "DEVELOPER:ISSUE" "Circular import in models.py"
  journal-log "DEVELOPER:RESOLVED" "Refactored to use dependency injection"
  ```

### QA
- **Role**: Testing and quality assurance
- **Responsibilities**: Test execution, bug finding, real service testing
- **Creates**: TEST_REPORT.md, bug reports
- **Hands off to**: REVIEWER (if passed) or DEVELOPER (if fixes needed)
- **Critical Rule**: **MUST test against real services, NO mocks in integration tests**
- **Key Commands**:
  ```bash
  journal-log "QA:PASSED" "All integration tests passing"
  journal-log "QA:FAILED" "API endpoint returns 500 on edge case"
  ```

### REVIEWER
- **Role**: Code review
- **Responsibilities**: Quality checks, architecture compliance, security review
- **Creates**: REVIEW_REPORT.md, PR comments
- **Hands off to**: MERGER (if approved) or DEVELOPER (if changes needed)
- **Key Commands**:
  ```bash
  journal-log "REVIEWER:ISSUE" "SQL injection vulnerability in user input"
  journal-log "REVIEWER:APPROVED" "Code meets all quality standards"
  ```

### MERGER
- **Role**: Integration and deployment
- **Responsibilities**: Merging PRs, releases, documentation updates
- **Creates**: MERGE_REPORT.md, release tags
- **Completes**: Development cycle
- **Key Commands**:
  ```bash
  journal-log "MERGER:MERGED" "PR #42 merged to main"
  journal-log "MERGER:RELEASE" "v1.2.0 tagged and released"
  ```

## Workflow

```
ARCHITECT → DEVELOPER → QA → REVIEWER → MERGER
    ↓                    ↕        ↕         ↓
    └────────────────────┴────────┴─────────┘
         (cycle continues or restarts)
```

## Critical Protocol Rules

### 1. Work Item Management
**NEVER** work without explicit work items:
```bash
# Check for pending work FIRST
journal-query.sh pending-work DEVELOPER

# Mark work as started
journal-log "WORK:STARTED" "DEVELOPER: Create user authentication module"

# Complete work when done
journal-log "WORK:COMPLETED" "DEVELOPER: Create user authentication module"
```

### 2. Handoff Requirements
**NEVER** hand off with incomplete work:
```bash
# Check handoff readiness
journal-query.sh handoff-ready DEVELOPER

# Only proceed if all work is complete
developer-handoff.sh
```

### 3. Safety Mechanisms
The system prevents infinite loops through:
- **Iteration Counting**: Maximum 10 initializations per persona
- **Progress Checking**: Must show completed work to continue
- **Work Validation**: Cannot hand off with pending items
- **Stuck Detection**: Alerts when no progress is made

## Journal-Based Memory

Each persona logs activities to `~/workspace/JOURNAL.md` with structured tags. The journal serves as persistent memory that survives context switches and session restarts.

### Event Types

#### Work Events
- `[WORK:PENDING]` - Work item needs to be done
- `[WORK:STARTED]` - Work has begun (prevents duplicate processing)
- `[WORK:COMPLETED]` - Work is finished
- `[WORK:BLOCKED]` - Work cannot proceed (with reason)

#### Handoff Events
- `[HANDOFF:REQUEST]` - Persona wants to hand off
- `[HANDOFF:VALIDATED]` - Requirements checked and passed
- `[HANDOFF:COMPLETED]` - Next persona can begin
- `[HANDOFF:BLOCKED]` - Cannot hand off (with reason)

#### Safety Events
- `[SAFETY:LIMIT]` - Safety threshold exceeded
- `[PERSONA:STUCK]` - No progress detected

### Logging Commands

Use the `journal-log` command to avoid echo approval prompts:

```bash
# Log architectural decision
journal-log "ARCHITECT:DECISION" "Chose PostgreSQL for ACID compliance"

# Log work progress
journal-log "WORK:STARTED" "DEVELOPER: Implement user model"

# Log test result
journal-log "QA:PASSED" "Integration tests with real backend passing"
```

### Journal Tags Reference

- `[PERSONA:INIT]` - Initialization
- `[PERSONA:SWITCH]` - Persona change
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
2. Safety checks are performed
3. Pending work is displayed with explicit instructions
4. Previous context is loaded from journal
5. **The full persona protocol is displayed inline**
6. You should follow the displayed protocol

### Understanding the Display

When initializing a persona, you'll see:
```
=== Found 3 pending work items ===
1. DEVELOPER: Create feature branch feat/backend-api
2. DEVELOPER: Write failing tests for user model
3. DEVELOPER: Implement user model to pass tests

Your immediate task:
→ Create feature branch feat/backend-api

Action plan:
1. Start this work item:
   journal-log 'WORK:STARTED' 'DEVELOPER: Create feature branch feat/backend-api'
2. Execute: git checkout -b feat/backend-api
3. Complete: journal-log 'WORK:COMPLETED' 'DEVELOPER: Create feature branch feat/backend-api'
```

### Handoffs

```bash
# Complete work and hand off to next persona
/home/devuser/.claude/personas/[persona]/[persona]-handoff.sh

# Example: Developer hands off to QA
/home/devuser/.claude/personas/developer/developer-handoff.sh
```

Handoff scripts:
1. Check all work is complete
2. Validate completion criteria
3. Create work items for next persona
4. Generate handoff documents (e.g., HANDOFF_TO_QA.md)
5. Log the transition
6. Automatically activate the next persona

### Context Recovery

If context is lost, personas can reconstruct their state:

```bash
# Show current context with highlighting
get-context-window.sh DEVELOPER

# Show work summary
journal-query.sh work-summary DEVELOPER

# Check pending handoffs
journal-query.sh handoff-chain

# View journal statistics
journal-stats.sh 7  # Last 7 days
```

## Utility Scripts

### Journal Query Tools
- `journal-query.sh pending-work [PERSONA]` - Show pending work items
- `journal-query.sh handoff-ready [PERSONA]` - Check if ready to hand off
- `journal-query.sh safety-check [PERSONA]` - Check iteration limits
- `journal-query.sh work-summary [PERSONA]` - Summary of work states
- `journal-query.sh decisions [PERSONA]` - Show architectural decisions
- `journal-query.sh errors [PERSONA]` - Recent errors/blocks

### Work Tracking
- `work-tracker.sh '<work-pattern>' [PERSONA]` - Track specific work item lifecycle
- `get-context-window.sh [PERSONA] [lines]` - Get relevant context
- `journal-stats.sh [days]` - Journal statistics and health check

### Logging
- `journal-log <TAG> <MESSAGE>` - Log to journal without echo prompts

## Benefits

1. **Separation of Concerns**: Each persona focuses on their domain expertise
2. **Quality Gates**: Issues caught at appropriate stages
3. **Context Persistence**: Complete history survives restarts
4. **Audit Trail**: Full traceability of decisions and actions
5. **Team Simulation**: Realistic development workflow
6. **Automation**: Reduces manual coordination overhead
7. **Safety**: Prevents infinite loops and stuck states

## Example Project Flow

1. **ARCHITECT** designs a GraphQL API system
   ```bash
   journal-log "ARCHITECT:DECISION" "GraphQL with Apollo Server"
   journal-log "ARCHITECT:MEMORY" "Real-time subscriptions required"
   architect-handoff.sh
   ```

2. **DEVELOPER** implements with TDD
   ```bash
   git checkout -b feat/graphql-api
   journal-log "DEVELOPER:CONTEXT" "Implementing GraphQL resolvers"
   # Write failing tests first
   # Implement code to pass tests
   developer-handoff.sh
   ```

3. **QA** tests against real services
   ```bash
   # Start real GraphQL server
   npm start &
   # Run integration tests against it
   journal-log "QA:PASSED" "All endpoints respond correctly"
   qa-handoff.sh
   ```

4. **REVIEWER** checks quality and compliance
   ```bash
   # Clone to isolated review directory
   cd ~/workspace/reviewer
   git clone ../hello-world hello-world-review
   journal-log "REVIEWER:APPROVED" "Code meets standards"
   reviewer-handoff.sh
   ```

5. **MERGER** integrates and releases
   ```bash
   gh pr merge --merge --no-squash
   journal-log "MERGER:RELEASE" "v1.0.0 - GraphQL API"
   git tag -a v1.0.0 -m "Initial GraphQL API release"
   merger-handoff.sh
   ```

## Troubleshooting

### Common Issues

#### Stuck Persona
```bash
# Check safety status
journal-query.sh safety-check DEVELOPER

# If stuck, check for:
# - Incomplete work items
# - Missing dependencies
# - Failed commands
```

#### Lost Context
```bash
# Rebuild context from journal
get-context-window.sh DEVELOPER 50

# Check recent handoffs
journal-query.sh handoff-chain
```

#### Work Not Progressing
```bash
# Track specific work item
work-tracker.sh "user authentication" DEVELOPER

# Check for blocks
journal-query.sh errors DEVELOPER
```

### Permission Denied
If you get "Permission denied" when running persona scripts:
```bash
chmod +x ~/.claude/personas/*/*.sh
```

### Journal Not Found
The journal is created automatically, but if missing:
```bash
touch ~/workspace/JOURNAL.md
echo "# Development Journal" > ~/workspace/JOURNAL.md
echo "$(date -Iseconds) [SYSTEM:INIT] Journal created" >> ~/workspace/JOURNAL.md
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
- `[persona]/[persona]-init.sh` - Initialization script with safety checks
- `[persona]/[persona]-handoff.sh` - Handoff script with validation

Modify these files to adjust persona behavior for your team's workflow.

## Best Practices

1. **Always Check Pending Work First** - Never assume what to do
2. **Mark Work Progress** - Use STARTED and COMPLETED states
3. **Create Specific Work Items** - Be explicit about tasks
4. **Test With Real Services** - Especially important for QA
5. **Document Decisions** - Use DECISION and MEMORY tags
6. **Handle Errors Gracefully** - Log issues and resolutions
7. **Complete Before Handoff** - Never leave work half-done

## Advanced Features

### Custom Hooks Integration
The persona system integrates with Claude Code's hook system:
- `persona-manager.sh` - Tracks persona switches
- `journal-context.sh` - Manages context queries
- `bash-logger.sh` - Logs all commands with categorization
- `decision-tracker.sh` - Records technical decisions
- `test-tracker.sh` - Monitors test execution

### Slash Commands
Available Claude Code commands:
- `/switch-persona [persona]` - Change active persona
- `/journal-summary` - View system-wide status
- `/show-context` - Display current context
- `/list-handoffs` - Show pending transitions

### Safety Features
- **Iteration Limits**: Max 10 inits per persona per session
- **Progress Requirements**: Must complete work to continue
- **Circular Dependency Detection**: Prevents infinite handoff loops
- **Stuck Detection**: Alerts when persona makes no progress

## Contributing

To improve the persona system:
1. Test changes thoroughly with example projects
2. Ensure safety mechanisms remain intact
3. Document new features in protocols
4. Update handoff validation as needed
5. Submit PR with example usage

---

*The multi-persona system transforms Claude Code into a complete development team, ensuring quality through structured workflows and persistent memory.*
