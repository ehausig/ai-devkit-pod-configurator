#!/bin/bash
# Claude Code pre-build script - Sets up autonomous development system with sub agents
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

log "Setting up Claude Code autonomous development system with sub agents..."

# Create necessary directories
mkdir -p "$TEMP_DIR/commands"
mkdir -p "$TEMP_DIR/hooks"
mkdir -p "$TEMP_DIR/agents"
mkdir -p "$TEMP_DIR/scripts"

# Copy user documentation
log "Copying user documentation..."
cp "$USER_CLAUDE" "$TEMP_DIR/"
success "Copied user-CLAUDE.md"

# Copy commands (only the ones we need for sub agent system)
if [[ -d "$SCRIPT_DIR/claude-code/commands" ]]; then
    log "Copying autonomous development commands..."
    # Copy all needed commands including create-prompt
    for cmd in init-autonomous show-journal event-query create-prompt; do
        if [[ -f "$SCRIPT_DIR/claude-code/commands/${cmd}.md" ]]; then
            cp "$SCRIPT_DIR/claude-code/commands/${cmd}.md" "$TEMP_DIR/commands/"
        fi
    done
    success "Copied $(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | wc -l) commands"
fi

# Copy autonomous continuation hook
if [[ -f "$SCRIPT_DIR/claude-code/hooks/autonomous-continue.sh" ]]; then
    log "Copying autonomous continuation hook..."
    cp "$SCRIPT_DIR/claude-code/hooks/autonomous-continue.sh" "$TEMP_DIR/hooks/"
    chmod +x "$TEMP_DIR/hooks/autonomous-continue.sh"
    success "Copied autonomous-continue.sh"
fi

# Copy sub agents
if [[ -d "$SCRIPT_DIR/claude-code/agents" ]]; then
    log "Copying sub agent definitions..."
    cp -r "$SCRIPT_DIR/claude-code/agents/"*.md "$TEMP_DIR/agents/" 2>/dev/null || true
    success "Copied $(ls -1 "$TEMP_DIR/agents/"*.md 2>/dev/null | wc -l) sub agents"
fi

# Copy utility scripts
if [[ -d "$SCRIPT_DIR/claude-code/scripts" ]]; then
    log "Copying utility scripts..."
    cp -r "$SCRIPT_DIR/claude-code/scripts/"*.sh "$TEMP_DIR/scripts/" 2>/dev/null || true
    success "Copied $(ls -1 "$TEMP_DIR/scripts/"*.sh 2>/dev/null | wc -l) scripts"
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

# Process command permissions from all selected components
log "Processing command permissions from selected components..."

# Initialize arrays for permissions
declare -a all_allow_perms=()
declare -a all_deny_perms=()

# Function to extract permissions from YAML
extract_permissions() {
    local yaml_file="$1"
    local perm_type="$2"  # "allow" or "deny"
    local in_permissions=false
    local in_target_section=false
    local indent_level=0
    
    while IFS= read -r line; do
        # Check if we're entering command_permissions section
        if [[ "$line" =~ ^command_permissions:[[:space:]]*$ ]]; then
            in_permissions=true
            continue
        fi
        
        # If we're in command_permissions
        if [[ "$in_permissions" == true ]]; then
            # Check if line starts with a non-space character (end of command_permissions)
            if [[ "$line" =~ ^[^[:space:]] ]]; then
                in_permissions=false
                in_target_section=false
                continue
            fi
            
            # Check for allow: or deny: section
            if [[ "$line" =~ ^[[:space:]]+${perm_type}:[[:space:]]*$ ]]; then
                in_target_section=true
                continue
            fi
            
            # Check if we're leaving the target section
            if [[ "$in_target_section" == true ]] && [[ "$line" =~ ^[[:space:]]+[^[:space:]-] ]]; then
                in_target_section=false
                continue
            fi
            
            # Extract permission if we're in the target section
            if [[ "$in_target_section" == true ]] && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
                local perm="${BASH_REMATCH[1]}"
                # Remove quotes if present
                perm="${perm#[\"\']}"
                perm="${perm%[\"\']}"
                echo "$perm"
            fi
        fi
    done < "$yaml_file"
}

# Process each selected YAML file for permissions
for yaml_file in $SELECTED_YAML_FILES; do
    if [ -f "$yaml_file" ]; then
        log "Checking $yaml_file for command permissions..."
        
        # Extract allow permissions
        while IFS= read -r perm; do
            [ -n "$perm" ] && all_allow_perms+=("$perm")
        done < <(extract_permissions "$yaml_file" "allow")
        
        # Extract deny permissions
        while IFS= read -r perm; do
            [ -n "$perm" ] && all_deny_perms+=("$perm")
        done < <(extract_permissions "$yaml_file" "deny")
    fi
done

# Deduplicate permissions
if [ ${#all_allow_perms[@]} -gt 0 ]; then
    readarray -t all_allow_perms < <(printf '%s\n' "${all_allow_perms[@]}" | sort -u)
fi
if [ ${#all_deny_perms[@]} -gt 0 ]; then
    readarray -t all_deny_perms < <(printf '%s\n' "${all_deny_perms[@]}" | sort -u)
fi

log "Found ${#all_allow_perms[@]} unique allow permissions and ${#all_deny_perms[@]} unique deny permissions"

# Generate the final settings.json with permissions
log "Generating claude-settings.json with dynamic permissions..."

# Function to escape JSON string
json_escape() {
    local str="$1"
    # Escape backslashes first, then quotes
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    # Escape other control characters
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Generate the permissions arrays as JSON
allow_json=""
for perm in "${all_allow_perms[@]}"; do
    if [ -n "$allow_json" ]; then
        allow_json+=","$'\n'
    fi
    allow_json+="      \"$(json_escape "$perm")\""
done

deny_json=""
for perm in "${all_deny_perms[@]}"; do
    if [ -n "$deny_json" ]; then
        deny_json+=","$'\n'
    fi
    deny_json+="      \"$(json_escape "$perm")\""
done

# Read the template and replace the permissions section
cat > "$TEMP_DIR/claude-settings.json" << EOF
{
  "theme": "dark",
  "verbose": true,
  "includeCoAuthoredBy": true,
  "env": {
    "CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR": "0",
    "DISABLE_AUTOUPDATER": "1",
    "DISABLE_BUG_COMMAND": "1",
    "DISABLE_COST_WARNINGS": "0",
    "DISABLE_ERROR_REPORTING": "1",
    "DISABLE_NON_ESSENTIAL_MODEL_CALLS": "0",
    "DISABLE_TELEMETRY": "1"
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "autonomous-continue.sh"
          }
        ]
      }
    ]
  },
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": [
${allow_json}
    ],
    "deny": [
${deny_json}
    ]
  }
}
EOF

success "Generated claude-settings.json with permissions"

# Copy the generated settings file to be used instead of template
cp "$TEMP_DIR/claude-settings.json" "$TEMP_DIR/claude-settings.json.template"

# Create a manifest of included files
cat > "$TEMP_DIR/MANIFEST.txt" << EOF
# Claude Code Autonomous Development System Manifest

## Core Files
- user-CLAUDE.md: User documentation
- claude-settings.json: Settings with dynamic permissions from components

## Commands ($(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | sed 's|.*/|  - |')

## Hooks
- autonomous-continue.sh: Stop hook for autonomous agent delegation

## Sub Agents ($(ls -1 "$TEMP_DIR/agents/"*.md 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/agents/"*.md 2>/dev/null | sed 's|.*/|  - |')

## System Overview
The autonomous development system uses:
1. Sub agents for each persona (product-manager, architect, developer, qa, reviewer, merger)
2. A journal (~/workspace/JOURNAL.md) for state persistence
3. A stop hook that reads NEXT_AGENT directives and continues autonomously
4. Clear handoff protocols between agents
5. Dynamic permissions based on selected components

To start: Use "/init-autonomous" command after describing your project.
EOF

success "Created manifest file"

log "Claude Code autonomous development system setup completed successfully!"
info "The system will activate when users run /init-autonomous"
info "Agents will work autonomously through the Stop hook"
info "Permissions have been dynamically generated from ${#SELECTED_YAML_FILES} components"
