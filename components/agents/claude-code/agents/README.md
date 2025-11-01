# Agent Persona Migration Notice

## Important: Agent Definitions Have Moved

As of this version, **agent persona definitions have been migrated to the AI Kanban component** to provide better integration between autonomous development and real-time visualization.

## What Changed

- **Before**: Agent personas were part of the `claude-code` component
- **After**: Agent personas are now part of the `ai-kanban` component

## How to Access Agent Personas

### Option 1: Use Both Components (Recommended)
Select both `claude-code` and `ai-kanban` components during build:
- ✅ Full Claude Code functionality (journaling, scripts, commands)
- ✅ Complete agent persona definitions  
- ✅ Real-time Kanban dashboard visualization
- ✅ Agent definitions available at `/home/devuser/.ai-kanban/agents/`
- ✅ Compatibility symlinks at `/home/devuser/.claude/agents/`

### Option 2: Claude Code Only
If you select only `claude-code`:
- ✅ Core Claude Code functionality (journaling, scripts, commands)
- ⚠️  Stub agent references with migration information
- ❌ No full agent persona definitions
- ❌ No Kanban dashboard

### Option 3: AI Kanban Only
If you select only `ai-kanban`:
- ❌ **Not recommended** - requires Claude Code for journaling system
- The build system should prevent this configuration

## Benefits of the New Structure

1. **Better Separation of Concerns**
   - Core functionality (journaling, scripts) remains in `claude-code`  
   - Visualization and personas are in `ai-kanban`

2. **Enhanced Visualization**
   - Real-time Kanban board shows agent activities
   - Better tracking of autonomous development progress

3. **Conditional Deployment**
   - Agent personas are only deployed when you want the full visualization
   - Smaller deployments when you only need core functionality

## Migration Path

1. **No Action Needed**: If you typically select both components, everything continues to work
2. **Update Build Selection**: If you only selected `claude-code` before, add `ai-kanban` to get full agent personas
3. **Scripts Continue Working**: All your existing autonomous development workflows remain unchanged

## Technical Details

- **Agent Location (New)**: `/home/devuser/.ai-kanban/agents/`
- **Compatibility Links**: `/home/devuser/.claude/agents/` (symlinks to ai-kanban)
- **Dashboard URL**: `http://localhost:3000` (when ai-kanban is included)
- **Core Scripts**: Still in `/home/devuser/.claude/scripts/`

## Support

If you encounter issues with this migration:
1. Ensure both `claude-code` and `ai-kanban` are selected during build
2. Verify agents are available at `/home/devuser/.claude/agents/`
3. Check the build logs for any agent setup errors

---

*This migration improves the system architecture while maintaining full backward compatibility when both components are selected.*