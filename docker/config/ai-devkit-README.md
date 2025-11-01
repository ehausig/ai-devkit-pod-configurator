# AI DevKit Configuration Directory

This directory (`~/.config/ai-devkit`) is reserved for AI DevKit component configurations and runtime data.

## Purpose

This directory serves as a centralized location for:
- Component-specific configuration files
- Runtime state and cache data
- User preferences and settings
- AI agent workspaces and data

## Usage by Components

### Claude Code
When the Claude Code component is installed, it may use this directory to store:
- Agent configurations
- Project-specific settings
- Command history
- Session state

### AI Kanban Dashboard
When the AI Kanban component is installed, it may use this directory for:
- Kanban board state
- Card configurations
- Journal data
- Metrics and analytics

### Other Components
Various other AI DevKit components may create subdirectories here for their specific needs.

## Directory Structure

When components are installed, you may see subdirectories like:
```
~/.config/ai-devkit/
├── claude-code/       # Claude Code configurations
├── kanban/           # Kanban board data
├── cache/            # Component cache files
└── state/            # Runtime state information
```

## Persistence

This directory is mounted to a persistent volume, so your configurations and data are preserved across container restarts.

## Note

If this directory is empty, it means no components requiring persistent configuration have been installed or have not yet created their configuration files.

---

*This directory was created by the AI DevKit Pod Configurator build system.*