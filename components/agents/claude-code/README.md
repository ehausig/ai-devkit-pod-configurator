# Claude Code Component - Autonomous AI Development System

## Overview

The Claude Code component transforms the AI DevKit into an autonomous software development platform. Using event sourcing and a multi-persona system, Claude Code can develop complete software solutions from a simple prompt without human intervention.

## Key Features

### 🤖 Fully Autonomous Development
- **End-to-End Creation**: From requirements to deployed software
- **Self-Directed Workflow**: Automatic persona transitions
- **No Human Intervention**: Complete development cycles autonomously
- **Intelligent Coordination**: Event-sourced memory system

### 📊 Event-Sourced Architecture
- **Journal as Event Store**: `~/workspace/JOURNAL.md` stores all events
- **Persistent Memory**: Survives context switches and restarts
- **Work Coordination**: Enables autonomous persona handoffs
- **Complete Audit Trail**: Every decision and action is traceable

### 👥 Multi-Persona System
- **ARCHITECT**: System design and planning
- **DEVELOPER**: TDD implementation
- **QA**: Comprehensive testing
- **REVIEWER**: Code quality assurance
- **MERGER**: Integration and deployment

## Quick Start - Autonomous Development

### 1. Deploy with Claude Code

Select Claude Code during the AI DevKit build process:

```bash
./build-and-deploy.sh
# Select "Claude Code (AI Assistant)" from the agents category
```

### 2. Create a Project Prompt

```bash
ssh devuser@localhost -p 2222

cat > ~/workspace/PROMPT.md << 'EOF'
Create a REST API for a todo list application with:
- User authentication (JWT)
- CRUD operations for todos
- PostgreSQL database
- Unit and integration tests
- Docker deployment
- API documentation
EOF
```

### 3. Start Autonomous Development

```bash
# Initialize the ARCHITECT persona
/home/devuser/.claude/personas/architect/architect-init.sh

# The system will now work autonomously through all personas
```

### 4. Monitor Progress

```bash
# In another terminal, watch the journal
tail -f ~/workspace/JOURNAL.md

# Or check status periodically
journal-query.sh stats
```

## How It Works

### Autonomous Flow

```
PROMPT.md → ARCHITECT → DEVELOPER → QA → REVIEWER → MERGER
              ↓                      ↕        ↕         ↓
              └──────────────────────┴────────┴─────────┘
                    (automatic transitions)
```

1. **ARCHITECT** reads PROMPT.md and creates design documents
2. **DEVELOPER** implements using TDD with work items from ARCHITECT
3. **QA** tests the implementation against real services
4. **REVIEWER** performs code review in isolated environment
5. **MERGER** integrates changes and prepares release

### Event Types

The system uses structured events in JOURNAL.md:

```bash
[WORK:PENDING]    # Work item created
[WORK:STARTED]    # Work begun (prevents duplicates)
[WORK:COMPLETED]  # Work finished
[HANDOFF:REQUEST] # Ready to transition
[HANDOFF:COMPLETED] # Next persona activated
```

### Work Queue System

- Handoff scripts create `WORK:PENDING` items
- `work-queue-monitor` hook detects handoffs
- Prepares executable scripts at `/tmp/execute-next-work.sh`
- Automatically triggers next persona

## Component Structure

```
claude-code/
├── claude-code.yaml          # Component definition
├── claude-code-setup.sh      # Pre-build script
├── user-CLAUDE.md           # System instructions
├── claude-settings.json.template # Claude Code config
├── commands/                # Slash commands
│   ├── execute-work.md     # Execute next work item
│   ├── journal-summary.md  # View system status
│   └── switch-persona.md   # Manual persona control
├── hooks/                   # Automation hooks
│   ├── work-queue-monitor.yaml
│   ├── persona-manager.yaml
│   └── bash-logger.yaml
├── personas/               # Persona definitions
│   ├── architect/         # System designer
│   ├── developer/         # Implementation
│   ├── qa/               # Testing
│   ├── reviewer/         # Code review
│   └── merger/           # Integration
└── scripts/              # Utility scripts
    ├── journal-query.sh  # Query event store
    ├── work-tracker.sh   # Manage work items
    └── hook-framework.sh # Hook system
```

## Manual Controls (Optional)

While designed for autonomous operation, manual controls are available:

### Slash Commands
- `/execute-work` - Execute next prepared work item
- `/journal-summary` - View overall system status
- `/switch-persona [persona]` - Manually switch personas
- `/work-status` - Check current work queue

### Shell Commands
```bash
# Query journal
journal-query.sh pending-work DEVELOPER
journal-query.sh work-summary ARCHITECT
journal-query.sh handoff-chain

# Track work
work-tracker.sh status
work-tracker.sh prepare DEVELOPER

# Get context
get-context-window.sh QA
```

## Customization

### Adding Custom Personas

1. Create persona directory:
```bash
mkdir -p ~/.claude/personas/security
```

2. Create init script:
```bash
cat > ~/.claude/personas/security/security-init.sh << 'EOF'
#!/bin/bash
# Security persona initialization
journal-log.sh "SECURITY:INIT" "Starting security audit"
# ... persona logic
EOF
```

3. Create protocol:
```bash
cat > ~/.claude/personas/security/SECURITY-PROTOCOL.md << 'EOF'
# SECURITY Persona Protocol
## Role Definition
Security auditing and vulnerability assessment...
EOF
```

### Modifying Work Patterns

Edit handoff scripts to change work generation:

```bash
# In architect-handoff.sh
journal-log.sh "WORK:PENDING" "DEVELOPER: Implement with your framework"
journal-log.sh "WORK:PENDING" "DEVELOPER: Add custom validation"
```

### Custom Hooks

Create new hooks for specific behaviors:

```yaml
# custom-hook.yaml
id: custom-validator
name: Custom Validation Hook
events:
  - PostToolUse
configuration:
  matcher: "Write"
  command: "/home/devuser/.claude/hooks/custom-validator.sh"
```

## Safety Features

### Iteration Limits
- Max 10 initializations per persona
- Prevents infinite loops
- Automatic safety checks

### Progress Tracking
- Must complete work to continue
- Detects stuck personas
- Alerts on no progress

### Work Validation
- Clean handoffs required
- All work must be addressed
- Dependency checking

## Troubleshooting

### Stuck Persona
```bash
# Check safety status
journal-query.sh safety-check DEVELOPER

# View recent errors
journal-query.sh errors DEVELOPER

# Force continue
/execute-work
```

### Missing Dependencies
```bash
# Ensure Node.js is installed (required)
node --version

# Check Claude Code installation
claude --version
```

### Journal Issues
```bash
# Verify journal exists
ls -la ~/workspace/JOURNAL.md

# Check journal health
journal-query.sh stats all
```

## Best Practices

1. **Clear Requirements**: Write detailed PROMPT.md files
2. **Resource Allocation**: Ensure adequate CPU/memory
3. **Monitor Initially**: Watch first cycle for smooth operation
4. **Trust the Process**: Avoid interrupting autonomous flow
5. **Review Journal**: Learn from decision history

## Integration with AI DevKit

The Claude Code component integrates seamlessly with other AI DevKit components:

- **Languages**: Works with any selected language
- **Build Tools**: Utilizes Maven, Gradle, etc.
- **Testing**: Leverages testing frameworks
- **Git**: Full git integration for version control

## Examples

### Web API Development
```markdown
# ~/workspace/PROMPT.md
Create a RESTful API for a blog platform with:
- User registration and authentication
- Article CRUD with categories
- Comment system with moderation
- PostgreSQL database
- Redis caching
- Full test coverage
```

### CLI Tool Development
```markdown
# ~/workspace/PROMPT.md
Build a command-line tool for system monitoring:
- CPU, memory, disk usage tracking
- Process management
- Log file analysis
- Configuration file support
- Colored output
- Cross-platform support
```

### Microservice Development
```markdown
# ~/workspace/PROMPT.md
Design a microservice for payment processing:
- Stripe integration
- Transaction logging
- Webhook handling
- Idempotency support
- Rate limiting
- Comprehensive error handling
```

## Contributing

To improve the Claude Code component:

1. Test changes with example projects
2. Ensure autonomous flow remains intact
3. Update persona protocols as needed
4. Document new features
5. Submit PR with examples

## License

This component is part of the AI DevKit Pod Configurator and follows the same MIT license.

---

*The Claude Code component enables truly autonomous AI-driven software development, transforming ideas into working software without human intervention.*
