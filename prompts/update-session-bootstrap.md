# Prompt for Updating Session Bootstrap Documentation

I need you to update the session bootstrap documentation for the following script/file. This documentation helps LLMs understand the project's key interfaces and workflows without requiring full implementation details.

**Target file to document**: `[SCRIPT_NAME]`

**Instructions for updating SESSION_BOOTSTRAP.md**:

1. **Header**: Explain this is a session bootstrap file that provides high-level context for LLM sessions
2. **Primary Purpose**: Capture the file's main responsibilities and role in the system
3. **Key Interfaces**: Document all important:
   - Command-line arguments and options
   - Main functions and entry points
   - Environment variables
   - Configuration files
4. **Dependencies**: List what the script requires:
   - External commands/tools
   - Library scripts
   - Configuration files
5. **Workflow**: Outline the high-level process:
   - Major phases or steps
   - Decision points
   - Data flow
6. **Side Effects**: Document what changes the script makes:
   - Files created or modified
   - Services started
   - Resources deployed
7. **Integration Points**: Show how it connects with other parts:
   - What calls this script
   - What this script calls
   - Data formats exchanged
8. **Error Handling**: Describe failure modes and recovery
9. **Keep implementation minimal**: Focus on WHAT not HOW

**Format requirements**:
- Clear markdown with proper headings
- Code blocks for command examples only
- Bullet points for lists
- Tables for complex relationships
- Update existing content if SESSION_BOOTSTRAP.md exists
- Place in `llm/SESSION_BOOTSTRAP.md` or append to existing file

**Example sections to include**:
```markdown
## [Script Name]

### Overview
[High-level description]

### Primary Purpose
[Main responsibility]

### Command-Line Interface
- Usage: `./script [options]`
- Options:
  - `--flag` - Description

### Key Functions
- `main()` - Entry point
- `process()` - Core logic

### Dependencies
- External: kubectl, docker
- Libraries: lib/helper.sh

### Workflow
1. Initialize
2. Process
3. Deploy

### Side Effects
- Creates: temp files
- Modifies: config
- Starts: services
```

Please analyze the provided script and create comprehensive session bootstrap documentation following these guidelines.