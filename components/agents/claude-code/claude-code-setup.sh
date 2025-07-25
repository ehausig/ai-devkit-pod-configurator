#!/bin/bash
# Claude Code pre-build script - Sets up autonomous development system
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
USER_CLAUDE="$SCRIPT_DIR/claude-code/user-CLAUDE.md"
SETTINGS_TEMPLATE="$SCRIPT_DIR/claude-code/claude-settings.json.template"

[[ ! -f "$USER_CLAUDE" ]] && error "user-CLAUDE.md not found in $SCRIPT_DIR/claude-code"
[[ ! -f "$SETTINGS_TEMPLATE" ]] && error "claude-settings.json.template not found in $SCRIPT_DIR/claude-code"

log "Setting up Claude Code autonomous development system..."

# Create necessary directories
mkdir -p "$TEMP_DIR/commands"
mkdir -p "$TEMP_DIR/hooks"
mkdir -p "$TEMP_DIR/personas"

# Copy user documentation
log "Copying user documentation..."
cp "$USER_CLAUDE" "$TEMP_DIR/"
success "Copied user-CLAUDE.md"

# Copy settings template
log "Copying settings template..."
cp "$SETTINGS_TEMPLATE" "$TEMP_DIR/"
success "Copied claude-settings.json.template"

# Copy commands
if [[ -d "$SCRIPT_DIR/claude-code/commands" ]]; then
    log "Copying Claude Code commands..."
    cp -r "$SCRIPT_DIR/claude-code/commands/"*.md "$TEMP_DIR/commands/" 2>/dev/null || true
    success "Copied $(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | wc -l) commands"
fi

# Copy orchestration hook
if [[ -f "$SCRIPT_DIR/claude-code/hooks/orchestrate.sh" ]]; then
    log "Copying orchestration hook..."
    cp "$SCRIPT_DIR/claude-code/hooks/orchestrate.sh" "$TEMP_DIR/hooks/"
    chmod +x "$TEMP_DIR/hooks/orchestrate.sh"
    success "Copied orchestrate.sh"
fi

# Copy persona protocols
if [[ -d "$SCRIPT_DIR/claude-code/personas" ]]; then
    log "Copying persona protocols..."
    cp -r "$SCRIPT_DIR/claude-code/personas/"*.md "$TEMP_DIR/personas/" 2>/dev/null || true
    success "Copied $(ls -1 "$TEMP_DIR/personas/"*.md 2>/dev/null | wc -l) persona protocols"
fi

# Generate component imports file
log "Generating component imports for user CLAUDE.md..."

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
        # Extract component info
        comp_name=""
        comp_version=""
        comp_description=""
        
        while IFS= read -r line; do
            if [[ "$line" =~ ^name:[[:space:]]*(.+)$ ]]; then
                comp_name="${BASH_REMATCH[1]}"
                comp_name="${comp_name#[\"\']}"
                comp_name="${comp_name%[\"\']}"
            elif [[ "$line" =~ ^version:[[:space:]]*(.+)$ ]]; then
                comp_version="${BASH_REMATCH[1]}"
                comp_version="${comp_version#[\"\']}"
                comp_version="${comp_version%[\"\']}"
            elif [[ "$line" =~ ^description:[[:space:]]*(.+)$ ]]; then
                comp_description="${BASH_REMATCH[1]}"
                comp_description="${comp_description#[\"\']}"
                comp_description="${comp_description%[\"\']}"
            fi
        done < "$yaml_file"
        
        # Extract category
        category=$(basename "$(dirname "$yaml_file")")
        
        # Record component
        echo "${category}|${comp_name}|${comp_version}|${comp_description}" >> "$TEMP_COMPONENTS"
        
        # Record category if new
        if ! grep -q "^${category}$" "$TEMP_CATEGORIES"; then
            echo "$category" >> "$TEMP_CATEGORIES"
        fi
    fi
done

# Write components by category
while IFS= read -r category; do
    [ -z "$category" ] && continue
    
    # Category header
    echo "## ${category^}" >> "$IMPORTS_OUTPUT"
    echo "" >> "$IMPORTS_OUTPUT"
    
    # List components in category
    while IFS='|' read -r cat name ver desc; do
        if [ "$cat" = "$category" ]; then
            echo -n "- **$name**" >> "$IMPORTS_OUTPUT"
            [ -n "$ver" ] && echo -n " v$ver" >> "$IMPORTS_OUTPUT"
            [ -n "$desc" ] && echo -n " - $desc" >> "$IMPORTS_OUTPUT"
            echo "" >> "$IMPORTS_OUTPUT"
        fi
    done < "$TEMP_COMPONENTS"
    echo "" >> "$IMPORTS_OUTPUT"
done < "$TEMP_CATEGORIES"

# Cleanup temp files
rm -f "$TEMP_CATEGORIES" "$TEMP_COMPONENTS"

success "Component imports generated"

# Create a manifest of included files
cat > "$TEMP_DIR/MANIFEST.txt" << EOF
# Claude Code Autonomous Development System Manifest

## Core Files
- user-CLAUDE.md: User documentation
- claude-settings.json.template: Settings with orchestration hook

## Commands ($(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | sed 's|.*/|  - |')

## Hooks
- orchestrate.sh: Stop hook for autonomous orchestration (bash)

## Persona Protocols ($(ls -1 "$TEMP_DIR/personas/"*.md 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/personas/"*.md 2>/dev/null | sed 's|.*/|  - |')

## System Overview
The autonomous development system uses:
1. Commands for each persona (architect, developer, qa, reviewer, merger)
2. A journal (~/workspace/JOURNAL.md) for event sourcing
3. A bash orchestration hook that runs after each Claude response
4. Clear protocols for each persona's responsibilities

To start: Use "/init-project" command after describing your project.
EOF

success "Created manifest file"

log "Claude Code autonomous development system setup completed successfully!"
info "The system will activate when users run /init-project"
info "Personas will work autonomously through the Stop hook"
