# META-tests Documentation

> **Note**: This is a META documentation file that describes test files that exist in the project but whose full implementation is not shown here. This document captures the essential interfaces, behaviors, and interactions without implementation details.

## Overview

This directory contains the comprehensive test suite for the Claude Code event-driven autonomous development system. The tests validate the core event sourcing mechanics, CQRS projections, persona orchestration, and system robustness without requiring external tool dependencies.

## Test Files

### run-all-tests.sh

**Primary Purpose**: Master test runner that executes all test suites in sequence and provides aggregate results.

**Command-Line Interface**:
```bash
./run-all-tests.sh
# No arguments - runs all tests automatically
```

**Key Capabilities**:
- Discovers and runs all test-*.sh files in the directory
- Manages test environment setup/teardown between suites
- Kills interfering processes before and after test runs
- Provides colored output and summary statistics
- Backs up and restores production journal during testing

**Dependencies**:
- All test-*.sh files in the same directory
- test-framework.sh for common utilities
- System commands: pkill, find, grep

**Side Effects**:
- Creates backup of ~/workspace/JOURNAL.md
- Kills any running persona actors and event monitors
- Creates temporary test journals in /tmp
- Cleans up old journal backups (>1 hour old)

**Exit Codes**:
- 0: All test suites passed
- 1: One or more test suites failed

### test-framework.sh

**Primary Purpose**: Common testing utilities and assertion framework for all test suites.

**Key Functions**:
- `setup_test()` - Initialize test environment
- `teardown_test()` - Clean up after tests
- `run_tests()` - Main test runner logic
- `assert_equals(expected, actual, message)` - Basic equality assertion
- `assert_contains(haystack, needle, message)` - String containment assertion
- `assert_not_contains(haystack, needle, message)` - Negative containment
- `assert_event_exists(event_type, message)` - Journal event verification
- `assert_exit_code(expected, actual, message)` - Exit code verification
- `assert_file_exists(filepath, message)` - File existence check
- `assert_work_executed(exit_code, work_desc)` - Work execution assertion
- `wait_for_event(pattern, timeout)` - Wait for journal event
- `emit_mock_tool_event(tool, operation, result, persona)` - Mock tool operations
- `mock_git_operation(operation, details, persona)` - Mock git commands
- `mock_execute_command(cmd, description, persona)` - Mock command execution

**Global Variables**:
- `TESTS_RUN` - Total assertions executed (exported)
- `TESTS_PASSED` - Successful assertions (exported)
- `TESTS_FAILED` - Failed assertions (exported)
- `TEST_JOURNAL` - Current test journal path
- `TEST_ORIGINAL_DIR` - Directory to restore after tests

**Key Features**:
- Colored output (green/red/yellow/blue)
- Process cleanup between tests
- Unique journal per test function
- Exported counters for subshell compatibility
- Mock helpers for tool operations

### test-actors.sh

**Primary Purpose**: Tests the basic actor loading and mock execution functionality.

**Test Coverage**:
- Actor script loading in test mode
- Mock work execution
- Persona state verification
- Test helper utilities

**Key Functions Tested**:
- `load_actor_for_test()` - Load actor in test mode
- `simulate_work_execution()` - Simulate work assignment and execution
- `verify_persona_state()` - Check persona state via projections
- `create_test_actor_wrapper()` - Create test wrappers for actors

### test-event-emit.sh

**Primary Purpose**: Validates the event emission system and journal writing.

**Test Coverage**:
- Event format validation
- Required field checking
- Human-readable log generation
- Timestamp formatting
- Event type validation
- Special event types (DECISION, MEMORY, ISSUE)

**Key Validations**:
- WORK_ASSIGNED requires TO, ID, and WORK fields
- WORK_STARTED/COMPLETED require PERSONA and WORK_ID
- PERSONA_ACTIVATED requires PERSONA field
- HANDOFF_READY requires FROM and TO fields
- ISO 8601 timestamp format
- Human-readable entries for key events

### test-event-monitor.sh

**Primary Purpose**: Tests the event monitor that activates personas based on journal events.

**Test Coverage**:
- Monitor startup and shutdown
- Work assignment triggers persona activation
- Zombie process detection and handling
- Handoff processing
- Singleton enforcement
- Idle persona reactivation
- Cycle completion handling
- Initial event processing

**Key Scenarios**:
- Multiple work assignments to same persona
- Concurrent persona activation
- Process death and reactivation
- Handoff chains between personas
- Unprocessed handoff detection

### test-full-workflow.sh

**Primary Purpose**: Integration tests for complete development workflows.

**Test Coverage**:
- Happy path: ARCHITECT → DEVELOPER → QA → REVIEWER → MERGER
- Rejection flow: REVIEWER → DEVELOPER → QA
- Concurrent persona work
- Work failure and recovery
- Multiple development cycles
- Decision and memory persistence
- Handoff chain validation
- Workflow statistics

**Key Workflows**:
- Complete feature implementation cycle
- Code review rejection and fixes
- Parallel work across personas
- Failed work retry patterns
- Cross-persona decision tracking

### test-hooks.sh

**Primary Purpose**: Tests the Claude Code hook system integration.

**Test Coverage**:
- Hook framework basics
- Bash command logging
- Decision tracking
- Error recovery hooks
- File milestone tracking
- Code formatting hooks
- Notification system
- Autonomous controller
- Event routing

**Hook Types Tested**:
- PreToolUse
- PostToolUse
- Stop
- Notification
- Tool-specific hooks (Bash, Write, Edit)

### test-integration.sh

**Primary Purpose**: Tests integration scenarios without executing real tools.

**Test Coverage**:
- Git repository operations (mocked)
- Multi-language project support
- Project structure creation
- CI/CD configuration
- Environment setup
- Documentation generation
- Dependency management
- Cross-persona workflows

**Languages Tested**:
- Python
- Node.js/JavaScript
- Go
- Rust

### test-merger-actor.sh

**Primary Purpose**: Tests the MERGER persona functionality.

**Test Coverage**:
- CI/CD verification
- PR merge operations
- Changelog generation
- Release tagging
- Branch cleanup
- Integration testing
- Handoff logic
- Release notes creation

**Key Operations**:
- Git operations (mocked)
- GitHub CLI operations (mocked)
- Version management
- Documentation updates

### test-projections.sh

**Primary Purpose**: Tests the CQRS projection system for deriving state from events.

**Test Coverage**:
- Pending work filtering
- Current state detection
- Work history queries
- Next work selection
- Work description extraction
- Statistics generation
- Handoff detection
- System state overview
- Active persona listing

**Projection Types**:
- `pending_work` - Uncompleted work items
- `current_state` - ACTIVE/IDLE/COMPLETE/UNKNOWN
- `work_history` - Event trail for work items
- `decisions` - Persona decisions
- `stats` - Work statistics
- `system_state` - Overall system status

### test-qa-actor.sh

**Primary Purpose**: Tests the QA persona functionality.

**Test Coverage**:
- Unit test execution
- Coverage verification
- Integration testing
- Error handling verification
- Report generation
- Handoff decision logic
- Work item generation

**Key Features**:
- Test framework detection
- Coverage threshold checking (80%)
- Real service testing emphasis
- Issue tracking

### test-reviewer-actor.sh

**Primary Purpose**: Tests the REVIEWER persona functionality.

**Test Coverage**:
- Code quality checks
- Architecture compliance
- Security vulnerability detection
- Error handling verification
- Documentation review
- Handoff logic
- Work generation
- Review report creation

**Review Types**:
- Linting and style
- Security scanning
- Architecture conformance
- Test coverage
- Documentation quality

### test-robustness.sh

**Primary Purpose**: Tests system robustness and edge cases.

**Test Coverage**:
- Journal corruption recovery
- Concurrent event emission
- Large journal performance
- Disk space handling
- Malformed event rejection
- Journal line integrity
- Special character handling
- Rapid event emission
- Crash recovery

**Edge Cases**:
- Partial writes
- Invalid event formats
- Unicode and special characters
- File locking under load
- 1000+ event journals

## Environment Variables

**Test Mode**:
- `TEST_MODE=1` - Enables test mode in actors
- `DEBUG=1` - Enables debug output
- `JOURNAL_FILE` - Path to test journal
- `ACTOR_RUNTIME_MODE` - Set to "test" for actors

**Test Tracking**:
- `TEST_JOURNAL` - Current test journal path
- `TEST_ORIGINAL_DIR` - Directory restoration

## Key Interactions

### Test Hierarchy
```
run-all-tests.sh
  ├── test-framework.sh (sourced by all)
  ├── test-actors.sh
  ├── test-event-emit.sh
  ├── test-event-monitor.sh
  ├── test-full-workflow.sh
  ├── test-hooks.sh
  ├── test-integration.sh
  ├── test-merger-actor.sh
  ├── test-projections.sh
  ├── test-qa-actor.sh
  ├── test-reviewer-actor.sh
  └── test-robustness.sh
```

### System Components Tested
- **Event System**: es-event-emit.sh, es-event-monitor.sh, es-projection.sh
- **Actors**: All persona actors (ARCHITECT, DEVELOPER, QA, REVIEWER, MERGER)
- **Hooks**: Claude Code hook framework and specific hooks
- **Journal**: Event sourcing and CQRS mechanics

## Critical Assumptions

1. **Test Isolation**: Each test function runs in isolation with its own journal
2. **Mock Operations**: All external tools (git, npm, etc.) are mocked via journal events
3. **Process Management**: Tests can kill persona actors and monitors without affecting other processes
4. **Journal Format**: Events follow strict format: `[EVENT] TYPE:name|FIELD:value|...`
5. **Counter Export**: Test counters must be exported for subshell compatibility

## Error Handling

**Process Cleanup**:
- Always kill existing processes before tests
- Clean up even on test failure (trap handlers)
- Remove temporary files and directories

**Assertion Failures**:
- Continue running remaining assertions
- Report all failures with details
- Return non-zero exit code if any test fails

**Timeout Handling**:
- Event waiting has configurable timeouts
- Default 5-second timeout for wait_for_event
- No timeout on test execution (removed for simplicity)

## Failure Modes

1. **Stale Processes**: Old monitors/actors interfere → killed before each test
2. **Journal Corruption**: Invalid entries → projections skip malformed lines
3. **Counter Mismatch**: Subshell isolation → counters exported after each update
4. **Race Conditions**: Concurrent events → file locking on journal writes
5. **Missing Dependencies**: Script not found → clear error messages

## Side Effects

**Files Created**:
- `/tmp/test-journal-*` - Temporary test journals
- `/tmp/test-actors-*` - Test actor wrappers
- `/tmp/es-event-monitor.pid` - Monitor PID tracking
- `/tmp/es-personas/` - Persona PID files
- `~/workspace/JOURNAL.md.backup-*` - Journal backups

**Processes Started**:
- Mock persona actors (brief execution)
- Event monitors (killed after tests)
- Background event emissions

**System Changes**:
- None - all operations are mocked
- No git commands executed
- No package installations
- No file system modifications outside /tmp
