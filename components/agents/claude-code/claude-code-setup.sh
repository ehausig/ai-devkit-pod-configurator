#!/bin/bash
# Claude Code pre-build script - Sets up autonomous development system with Team Topologies
# Generates component imports and prepares files for Docker build

# Standard arguments
TEMP_DIR="$1"
SELECTED_IDS="$2"
SELECTED_NAMES="$3"
SELECTED_YAML_FILES="$4"
SCRIPT_DIR="$5"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Utility functions
log() { echo -e "${YELLOW}$1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Verify required files exist
CLAUDE_TEMPLATE="$SCRIPT_DIR/claude-code/CLAUDE.md.template"
SETTINGS_TEMPLATE="$SCRIPT_DIR/claude-code/settings.json.template"
USER_LOCAL_SETTINGS="$SCRIPT_DIR/claude-code/settings.local.json.template"

[[ ! -f "$CLAUDE_TEMPLATE" ]] && error "$CLAUDE_TEMPLATE not found in $SCRIPT_DIR/claude-code"
[[ ! -f "$SETTINGS_TEMPLATE" ]] && error "$SETTINGS_TEMPLATE not found in $SCRIPT_DIR/claude-code"
[[ ! -f "$USER_LOCAL_SETTINGS" ]] && error "$USER_LOCAL_SETTINGS not found in $SCRIPT_DIR/claude-code"

log "Setting up Claude Code autonomous development system..."

# Create necessary directories
mkdir -p "$TEMP_DIR/commands"
mkdir -p "$TEMP_DIR/agents"
mkdir -p "$TEMP_DIR/scripts"
mkdir -p "$TEMP_DIR/docs"
mkdir -p "$TEMP_DIR/hooks"

# Copy CLAUDE template
cp "$CLAUDE_TEMPLATE" "$TEMP_DIR/CLAUDE.md"

# Copy settings template with FINAL name (not template name)
cp "$SETTINGS_TEMPLATE" "$TEMP_DIR/settings.json"

# Copy workspace settings template
cp "$USER_LOCAL_SETTINGS" "$TEMP_DIR/settings.local.json"

# Copy commands (all .md files)
if [[ -d "$SCRIPT_DIR/claude-code/commands" ]]; then
    log "Copying autonomous development commands..."
    if ls "$SCRIPT_DIR/claude-code/commands/"*.md >/dev/null 2>&1; then
        cp "$SCRIPT_DIR/claude-code/commands/"*.md "$TEMP_DIR/commands/"
        success "Copied $(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | wc -l) commands"
    else
        log "No command files found"
    fi
fi

# Copy agents (all .md files)
if [[ -d "$SCRIPT_DIR/claude-code/agents" ]]; then
    log "Copying agent definitions..."
    if ls "$SCRIPT_DIR/claude-code/agents/"*.md >/dev/null 2>&1; then
        cp "$SCRIPT_DIR/claude-code/agents/"*.md "$TEMP_DIR/agents/"
        success "Copied $(ls -1 "$TEMP_DIR/agents/"*.md 2>/dev/null | wc -l) agents"
    else
        log "No agent files found"
    fi
fi

# Copy hooks (all .sh files if directory exists)
if [[ -d "$SCRIPT_DIR/claude-code/hooks" ]]; then
    log "Copying hook scripts..."
    if ls "$SCRIPT_DIR/claude-code/hooks/"*.sh >/dev/null 2>&1; then
        cp "$SCRIPT_DIR/claude-code/hooks/"*.sh "$TEMP_DIR/hooks/"
        chmod +x "$TEMP_DIR/hooks/"*.sh
        success "Copied $(ls -1 "$TEMP_DIR/hooks/"*.sh 2>/dev/null | wc -l) hooks"
    else
        log "No hook files found"
    fi
fi

# Copy utility scripts
if [[ -d "$SCRIPT_DIR/claude-code/scripts" ]]; then
    log "Copying utility scripts..."
    if ls "$SCRIPT_DIR/claude-code/scripts/"*.sh >/dev/null 2>&1; then
        cp "$SCRIPT_DIR/claude-code/scripts/"*.sh "$TEMP_DIR/scripts/"
        chmod +x "$TEMP_DIR/scripts/"*.sh
        success "Copied $(ls -1 "$TEMP_DIR/scripts/"*.sh 2>/dev/null | wc -l) scripts"
    else
        log "No script files found"
    fi
fi

# Note: Component documentation files are already copied to $TEMP_DIR/docs/ by build-and-deploy.sh
# This script only needs to generate the import references

# Count component docs for logging
local docs_count=$(ls -1 "$TEMP_DIR/docs/"*.md 2>/dev/null | wc -l)
if [[ $docs_count -gt 0 ]]; then
    log "Found $docs_count component documentation files in docs folder"
else
    log "No component documentation files found in docs folder"
fi

# Generate component imports file with import syntax
log "Generating component imports with @import syntax..."

IMPORTS_OUTPUT="$TEMP_DIR/component-imports.txt"
cat > "$IMPORTS_OUTPUT" << 'EOF'

---

# Installed Components

This environment includes the following components:

EOF

# Process selected components
TEMP_CATEGORIES="$TEMP_DIR/.categories.tmp"
TEMP_COMPONENTS="$TEMP_DIR/.components.tmp"
> "$TEMP_CATEGORIES"
> "$TEMP_COMPONENTS"

# Process each YAML file
for yaml_file in $SELECTED_YAML_FILES; do
    if [ -f "$yaml_file" ]; then
        # Extract component info using yq
        comp_name=$(yq eval '.name // ""' "$yaml_file")
        comp_version=$(yq eval '.version // ""' "$yaml_file")
        comp_description=$(yq eval '.description // ""' "$yaml_file")
        
        # Extract category
        category=$(basename "$(dirname "$yaml_file")")
        
        # Get the yaml basename for checking if md file exists
        yaml_basename=$(basename "$yaml_file" .yaml)
        
        # Record component
        echo "${category}|${comp_name}|${comp_version}|${comp_description}|${yaml_basename}" >> "$TEMP_COMPONENTS"
        
        # Record category if new
        if ! grep -q "^${category}$" "$TEMP_CATEGORIES"; then
            echo "$category" >> "$TEMP_CATEGORIES"
        fi
    fi
done

# Write components by category
while IFS= read -r category; do
    [ -z "$category" ] && continue
    
    # Category header - properly format the display name
    case "$category" in
        "languages")
            cat_display="Languages"
            ;;
        "agents")
            cat_display="AI Agents"
            ;;
        "databases")
            cat_display="Databases"
            ;;
        "tools")
            cat_display="Development Tools"
            ;;
        "frameworks")
            cat_display="Frameworks"
            ;;
        *)
            # Default: capitalize first letter using awk (more portable)
            cat_display=$(echo "$category" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
            ;;
    esac
    
    echo "## $cat_display" >> "$IMPORTS_OUTPUT"
    echo "" >> "$IMPORTS_OUTPUT"
    
    # List components in category
    while IFS='|' read -r cat name ver desc basename; do
        if [ "$cat" = "$category" ]; then
            echo -n "- **$name**" >> "$IMPORTS_OUTPUT"
            [ -n "$ver" ] && echo -n " v$ver" >> "$IMPORTS_OUTPUT"
            [ -n "$desc" ] && echo -n " - $desc" >> "$IMPORTS_OUTPUT"
            
            # Add import reference if md file exists
            if [[ -f "$TEMP_DIR/docs/${basename}.md" ]]; then
                echo -n " @/home/devuser/.claude/docs/${basename}.md" >> "$IMPORTS_OUTPUT"
            fi
            
            echo "" >> "$IMPORTS_OUTPUT"
        fi
    done < "$TEMP_COMPONENTS"
    echo "" >> "$IMPORTS_OUTPUT"
done < "$TEMP_CATEGORIES"

# Cleanup temp files
rm -f "$TEMP_CATEGORIES" "$TEMP_COMPONENTS"

success "Component imports generated with @import syntax"

# Process command permissions from all selected components
log "Processing command permissions from selected components..."

# Initialize arrays for permissions
declare -a all_allow_perms=()
declare -a all_deny_perms=()

# Process each selected YAML file for permissions using yq
for yaml_file in $SELECTED_YAML_FILES; do
    if [ -f "$yaml_file" ]; then
        log "Checking $(basename "$yaml_file") for command permissions..."
        
        # Extract allow permissions using yq
        while IFS= read -r perm; do
            if [ -n "$perm" ]; then
                all_allow_perms+=("$perm")
            fi
        done < <(yq eval '.command_permissions.allow[]' "$yaml_file" 2>/dev/null || true)
        
        # Extract deny permissions using yq
        while IFS= read -r perm; do
            if [ -n "$perm" ]; then
                all_deny_perms+=("$perm")
            fi
        done < <(yq eval '.command_permissions.deny[]' "$yaml_file" 2>/dev/null || true)
    fi
done

# Deduplicate permissions while preserving array elements with spaces
if [ ${#all_allow_perms[@]} -gt 0 ]; then
    # Use a temporary file to preserve spaces during deduplication
    temp_allow="$TEMP_DIR/temp_allow_perms.txt"
    printf '%s\n' "${all_allow_perms[@]}" | sort -u > "$temp_allow"
    all_allow_perms=()
    while IFS= read -r perm; do
        all_allow_perms+=("$perm")
    done < "$temp_allow"
    rm -f "$temp_allow"
fi

if [ ${#all_deny_perms[@]} -gt 0 ]; then
    # Use a temporary file to preserve spaces during deduplication
    temp_deny="$TEMP_DIR/temp_deny_perms.txt"
    printf '%s\n' "${all_deny_perms[@]}" | sort -u > "$temp_deny"
    all_deny_perms=()
    while IFS= read -r perm; do
        all_deny_perms+=("$perm")
    done < "$temp_deny"
    rm -f "$temp_deny"
fi

log "Found ${#all_allow_perms[@]} unique allow permissions and ${#all_deny_perms[@]} unique deny permissions from components"

log "Copying settings.json template..."
cp "$SETTINGS_TEMPLATE" "$TEMP_DIR/settings.json"

# Generate the workspace settings
log "Generating settings.local.json with dynamic permissions..."

# Create the JSON structure using jq
jq -n \
  --argjson allow "$(printf '%s\n' "${all_allow_perms[@]}" | jq -R . | jq -s .)" \
  --argjson deny "$(printf '%s\n' "${all_deny_perms[@]}" | jq -R . | jq -s .)" \
  '{permissions: {allow: $allow, deny: $deny}}' > "$TEMP_DIR/settings.local.json"

success "Generated settings.local.json with permissions"

# Verify the JSON is valid
if jq . "$TEMP_DIR/settings.local.json" >/dev/null 2>&1; then
    success "JSON validation passed"
else
    error "Generated JSON is invalid!"
fi

# Create a manifest of included files
cat > "$TEMP_DIR/MANIFEST.txt" << EOF
# Claude Code Autonomous Development System Manifest

## Core Files
- CLAUDE.md: Product Manager orchestration guide with dynamic refs
- settings.json: Global settings
- settings.local.json: Workspace settings with dynamic permissions

## Commands ($(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | sed 's|.*/|  - |' | sort)

## Agents ($(ls -1 "$TEMP_DIR/agents/"*.md 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/agents/"*.md 2>/dev/null | sed 's|.*/|  - |' | sort)

## Utility Scripts ($(ls -1 "$TEMP_DIR/scripts/"*.sh 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/scripts/"*.sh 2>/dev/null | sed 's|.*/|  - |' | sort)

## Hooks ($(ls -1 "$TEMP_DIR/hooks/"*.sh 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/hooks/"*.sh 2>/dev/null | sed 's|.*/|  - |' | sort)

## Component Documentation ($(ls -1 "$TEMP_DIR/docs/"*.md 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/docs/"*.md 2>/dev/null | sed 's|.*/|  - |' | sort)

## System Overview
The autonomous development system uses:
1. Product Manager (main thread) as orchestrator
2. Team Topologies-based organization
3. Kanban card system for work tracking
4. JOURNAL.md for state persistence
5. Deterministic handoffs between teams
6. No reliance on hooks for orchestration (hooks are optional)

To start: Use "/init-autonomous" command after describing your project.
EOF

success "Created manifest file"

# Debug: Show some extracted permissions
if [ ${#all_allow_perms[@]} -gt 0 ]; then
    log "Sample of extracted permissions:"
    for i in {0..4}; do
        [ $i -lt ${#all_allow_perms[@]} ] && echo "  - ${all_allow_perms[$i]}"
    done
    [ ${#all_allow_perms[@]} -gt 5 ] && echo "  ... and $((${#all_allow_perms[@]} - 5)) more"
fi

log "Claude Code autonomous development system setup completed successfully!"
