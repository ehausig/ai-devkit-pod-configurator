# Session Bootstrap Instructions

## For Claude Code (or other LLMs)

This document provides essential instructions for starting a new development session on the AI DevKit Pod Configurator project.

## 🚀 Session Initialization

When starting a new session, read these files in order:

1. **This file** (`llm/BOOTSTRAP_SESSION.md`) - Session instructions
2. **`llm/PRINCIPLES.md`** - Core principles and architectural decisions
3. **`llm/CURRENT_STATE.md`** - Current project state and recent changes

## 📁 Project Structure Overview

```
ai-devkit-pod-configurator/
├── build-and-deploy.sh              # Main entry point with interactive TUI
├── setup-container-git-credentials.sh  # Git credential configuration
├── scripts/                         # Utility scripts
│   ├── cleanup-runtime.sh          # Multi-platform container cleanup
│   └── cleanup-build-animations.sh # TUI process cleanup
├── lib/                            # Core libraries (pure bash)
├── components/                     # Component definitions
│   ├── README.md                   # Component documentation
│   ├── agents/                     # AI assistants
│   ├── languages/                  # Programming languages
│   ├── build-deploy/              # Build tools
│   └── tools/                     # Development tools
├── docker/                        # Docker base images
├── docs/                          # Technical documentation
│   ├── architecture.md            # System architecture
│   ├── testing.md                 # Test plan
│   └── themes.md                  # TUI themes
└── llm/                           # LLM context files (THIS DIRECTORY)
    ├── BOOTSTRAP_SESSION.md       # This file
    ├── PRINCIPLES.md              # Core principles
    └── CURRENT_STATE.md           # Current state
```

## 🔑 Key Concepts

### Component System
- Components are self-contained units that define what to install
- Each component owns its entire configuration (no core dependencies)
- Components use YAML definitions with optional supporting files
- Pure plugin architecture - adding components requires zero core changes

### Build Process
1. User runs `build-and-deploy.sh`
2. Interactive TUI for component selection
3. Components processed to generate configurations
4. Docker image built with selected components
5. Deployed to Kubernetes with init container pattern
6. Files distributed to exact locations at runtime

### Configuration
- User must create `~/.ai-devkit/config.yaml` with container settings
- No runtime detection - explicit configuration only
- Pure bash implementation - zero Python dependencies

## 📝 Working with LLM Context Files

### CURRENT_STATE.md
**Purpose**: Track what's happening now
- Update after significant changes
- Record test results and fixes
- Note any new issues or blockers
- Keep "Next Actions" section current

**When to update**:
- After completing major tasks
- When discovering issues
- After running tests
- Before ending a session

### PRINCIPLES.md
**Purpose**: Govern behavior and decisions
- Contains architectural decisions (ADRs)
- Lists anti-patterns to avoid
- Documents lessons learned from issues

**When to update**:
- When discovering new principles from bugs
- After making architectural decisions
- When identifying new anti-patterns

**Never modify** unless adding new principles based on actual issues

### BOOTSTRAP_SESSION.md (This File)
**Purpose**: Help new sessions get oriented
- Should remain relatively stable
- Update only if project structure changes significantly
- Keep focused on orientation, not details

## ⚠️ Critical Rules

1. **Never add component-specific code to core scripts**
   - No package manager names in `build-and-deploy.sh`
   - No hardcoded paths like `/home/devuser/.npmrc`
   - Components own everything about themselves

2. **Never introduce Python dependencies in core**
   - Use bash for all core functionality
   - Template processing must be pure bash
   - Python only exists when explicitly selected as a component

3. **Always use explicit configuration**
   - No runtime detection of container tools
   - Require `~/.ai-devkit/config.yaml`
   - Fail fast with clear error messages

4. **Respect the init container pattern**
   - Build phase: stage files with manifest
   - Deploy phase: init container copies files
   - Runtime: main container has files in place

## 🎯 Common Tasks

### Adding a New Component
1. Create YAML definition in appropriate category
2. Add any supporting files in component directory
3. Create `ai-devkit/file-mappings.yaml` if needed
4. Add tests in `ai-devkit/tests/`
5. No core script changes needed!

### Debugging Build Issues
1. Check `build-and-deploy.log` for detailed output
2. Verify `~/.ai-devkit/config.yaml` exists and is valid
3. Look for staging issues in `.build-temp/staging/`
4. Check manifest at `.build-temp/staging/manifest.txt`

### Running Tests
1. Create config.yaml as specified in test
2. Run `./build-and-deploy.sh` with specified components
3. SSH into pod: `ssh -p 2222 devuser@localhost`
4. Run tests: `~/.ai-devkit/tests/run-all.sh`

## 🔍 Where to Find Things

- **Component definitions**: `components/*/*.yaml`
- **Build logic**: `build-and-deploy.sh`
- **Template processing**: `lib/template-processor-bash.sh`
- **File staging**: `lib/file-mapping-manager.sh`
- **Test definitions**: `docs/testing.md`
- **Architecture details**: `docs/architecture.md`

## 💡 Session Best Practices

1. **Start by reading the LLM context files** to understand current state
2. **Check CURRENT_STATE.md "Next Actions"** for immediate tasks
3. **Follow principles in PRINCIPLES.md** when making changes
4. **Update CURRENT_STATE.md** before ending session
5. **Test changes** with actual component builds
6. **Maintain clean git history** with clear commit messages

## 🚫 What NOT to Do

- Don't create new scripts without clear need
- Don't add process overhead (versioning, releases) prematurely  
- Don't modify core to support new components
- Don't assume runtime environment - use config
- Don't mix JSON and YAML in configs
- Don't skip updating CURRENT_STATE.md

## 📊 Current Status Summary

- **Working**: Core system fully functional
- **Testing**: 11 of 20 tests passing
- **Components**: 23 total, all migrated to new architecture
- **Documentation**: Streamlined to essential content
- **Branch**: feat/cross-platform-compatibility

## 🎬 Getting Started

If you're starting fresh:

1. Read this file completely
2. Read `llm/PRINCIPLES.md` to understand the rules
3. Read `llm/CURRENT_STATE.md` to see what's happening
4. Check "Next Actions" in CURRENT_STATE.md
5. Begin work, following the principles

Remember: This is a two-person project (human + Claude). Keep it simple, avoid premature abstraction, and focus on making things work.