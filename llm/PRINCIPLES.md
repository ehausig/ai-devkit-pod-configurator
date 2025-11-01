# Project Principles & Architecture Decisions

This document distills key principles, lessons learned, and architectural decisions that govern the AI DevKit Pod Configurator project.

## Core Architecture Principles

### 1. Configuration-Driven, Not Detection-Driven
**Decision**: All container runtime settings come from `~/.ai-devkit/config.yaml`
- **Rationale**: Runtime detection creates non-deterministic behavior
- **Implementation**: Fail-fast with explicit configuration requirements
- **Never**: Auto-detect container runtimes or make assumptions

### 2. Component Isolation & Zero Core Dependencies
**Decision**: Core scripts contain NO component-specific code
- **Rationale**: 400+ lines of hard-coded package manager logic violated separation of concerns
- **Implementation**: Components own their entire configuration through templates and manifests
- **Never**: Add package manager names, paths, or logic to core scripts

### 3. Pure Bash, Zero Python Dependencies
**Decision**: Core system uses only bash and standard Unix tools
- **Rationale**: Python dependency for templating violated "zero dependency" goal
- **Implementation**: Created bash-based template processor using native shell functions
- **Never**: Introduce Python, Ruby, or other language dependencies in core
- **Validation**: Test 1.1 verifies no Python in:
  - Core scripts (lib/*.sh, build-and-deploy.sh)
  - Base Docker image (docker/Dockerfile.base)
  - Template processing (must use bash functions)
  - YAML processing (must use Go-based yq, not Python-based)

### 4. YAML Over JSON
**Decision**: All configuration uses YAML format
- **Rationale**: Better readability, consistency, native Kubernetes format
- **Implementation**: Use yq for YAML processing (supports both kislyuk and mikefarah versions)
- **Never**: Mix JSON and YAML in configuration files

## Component System Principles

### 5. Components Own Everything
Components are responsible for:
- Installation instructions (Dockerfile snippets)
- Configuration templates (pip.conf, .npmrc, etc.)
- File mappings and volume mounts
- Repository definitions
- Verification tests
- Runtime initialization

### 6. Component IDs for K8s Resources
**Decision**: Use component IDs (not display names) for all Kubernetes resources
- **Pattern**: `PYTHON_3_11` → `python-3-11` (lowercase with dashes)
- **Rationale**: Display names create messy, unpredictable resource names
- **Never**: Use sanitized display names for ConfigMap keys or resource names

### 7. Test Co-location
**Decision**: Component tests live with components, injected at `~/.ai-devkit/tests/`
- **Rationale**: Tests should be versioned with their components
- **Implementation**: Test discovery and injection during build
- **Never**: Maintain separate test directories divorced from components

## Build & Deployment Principles

### 8. ConfigMap Timing
**Decision**: Create ConfigMaps during build, apply after namespace exists
- **Rationale**: ConfigMaps deleted during namespace cleanup if applied too early
- **Implementation**: Two-phase approach - generate then apply
- **Never**: Apply ConfigMaps before namespace creation

### 9. Explicit File Staging
**Decision**: All files must be explicitly staged to build context
- **Rationale**: Docker build can only access files in build context
- **Implementation**: Copy inject_files from component directories before build
- **Never**: Assume files are available without explicit staging

### 10. Global State Management
**Decision**: Preserve global state (like CONFIG_FILE) across processing phases
- **Rationale**: Component processing temporarily modifies global state
- **Implementation**: Save/restore pattern at appropriate scope levels
- **Never**: Modify global state without restoration plan

## Error Handling Principles

### 11. Graceful Degradation
**Decision**: Missing credentials generate warnings, not failures
- **Rationale**: Partial configuration better than no configuration
- **Implementation**: Warning messages in both stderr and config file comments
- **Never**: Fail builds for missing optional configuration

### 12. Array Safety with set -u
**Decision**: Always initialize arrays before use
- **Pattern**: `ARRAY=()` before any conditional population
- **Rationale**: Unbound variable errors with `set -u` enabled
- **Never**: Reference potentially unbound arrays

### 13. Shell Compatibility
**Decision**: Support both bash and zsh, handle shell-specific features
- **Implementation**: Avoid `export -f`, check for `set -e` context
- **Rationale**: Scripts may be sourced in different shell environments
- **Never**: Assume bash-only features are available

## Cross-Platform Principles

### 14. YQ Version Compatibility
**Decision**: Support both kislyuk/yq and mikefarah/yq implementations
- **Implementation**: Detect version and use appropriate syntax
- **Pattern**: Wrapper functions that abstract version differences
- **Never**: Hardcode paths or assume specific yq version

### 15. Container Tool Abstraction
**Decision**: Support docker, podman, nerdctl transparently
- **Implementation**: Detect and use available tools
- **Rationale**: Different platforms have different container tools
- **Never**: Hardcode docker commands

## Development Principles

### 16. Lean Until Needed
**Decision**: Avoid premature abstraction and process overhead
- **Examples**: No versioning until 1.0, no release process for two-person team
- **Rationale**: Process should match team size and project maturity
- **Never**: Create elaborate processes without actual need

### 17. Documentation Near Code
**Decision**: Keep documentation close to what it documents
- **Examples**: components/README.md instead of docs/components.md
- **Rationale**: Easier to maintain when documentation lives with code
- **Never**: Separate documentation unnecessarily from its subject

## Testing Principles

### 18. Explicit Test Specifications
**Decision**: Tests should specify exact components and configuration
- **Rationale**: "Select all components" fails due to mutual exclusions
- **Implementation**: List specific compatible component sets
- **Never**: Use vague instructions like "select all"

### 19. Test Isolation
**Decision**: Each test should create its own configuration
- **Implementation**: Generate fresh config.yaml for each test
- **Rationale**: Prevents test contamination from previous runs
- **Never**: Rely on existing user configuration for tests

## Key Lessons from Production Issues

### 20. ConfigMap Key Matching
**Learning**: Volume mount subPaths must exactly match ConfigMap data keys
- **Issue**: Files mounting as directories due to key mismatches
- **Solution**: Consistent sanitization pattern for all keys

### 21. Build Context Boundaries
**Learning**: Docker build cannot access files outside build context
- **Issue**: inject_files references failing during build
- **Solution**: Explicit file staging to .build-temp/

### 22. State Modification Scope
**Learning**: Global state changes need careful scope management
- **Issue**: CONFIG_FILE corruption across component processing
- **Solution**: Save/restore at appropriate function boundaries

## Anti-Patterns to Avoid

1. **Runtime Detection** - Always use explicit configuration
2. **Component Logic in Core** - Keep core pure orchestration
3. **Mixed Config Formats** - Stick to YAML throughout
4. **Python Dependencies** - Keep core bash-only
5. **Implicit File Access** - Always stage files explicitly
6. **Unguarded Arrays** - Initialize before use
7. **Shell-Specific Features** - Write portable scripts
8. **Hardcoded Paths** - Use dynamic discovery
9. **Vague Test Specs** - Be explicit about components
10. **Premature Process** - Match process to project maturity