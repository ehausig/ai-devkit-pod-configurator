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
SETTINGS_TEMPLATE="$SCRIPT_DIR/claude-code/claude-settings.json.template"
USER_LOCAL_SETTINGS="$SCRIPT_DIR/claude-code/claude-user-local-settings.json.template"

[[ ! -f "$CLAUDE_TEMPLATE" ]] && error "CLAUDE.md.template not found in $SCRIPT_DIR/claude-code"
[[ ! -f "$SETTINGS_TEMPLATE" ]] && error "claude-settings.json.template not found in $SCRIPT_DIR/claude-code"
[[ ! -f "$USER_LOCAL_SETTINGS" ]] && error "claude-user-local-settings.json.template not found in $SCRIPT_DIR/claude-code"

log "Setting up Claude Code autonomous development system with Team Topologies..."

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
cp "$USER_LOCAL_SETTINGS" "$TEMP_DIR/user-local-settings.json"

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
    
    # Category header (capitalize first letter)
    cat_display=$(echo "$category" | sed 's/^\(.\)/\U\1/')
    echo "## $cat_display" >> "$IMPORTS_OUTPUT"
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

# Check if yq is available
if command -v yq >/dev/null 2>&1; then
    log "Using yq for YAML parsing"
else
    log "yq not found, using fallback YAML parser"
fi

# Initialize arrays for permissions
declare -a all_allow_perms=()
declare -a all_deny_perms=()

# Function to extract permissions from YAML
extract_permissions_from_yaml() {
    local yaml_file="$1"
    local perm_type="$2"  # "allow" or "deny"
    
    # Use yq for proper YAML parsing
    yq eval ".command_permissions.${perm_type}[]" "$yaml_file" 2>/dev/null || true
}

# Process each selected YAML file for permissions
for yaml_file in $SELECTED_YAML_FILES; do
    if [ -f "$yaml_file" ]; then
        log "Checking $(basename "$yaml_file") for command permissions..."
        
        # Debug: Check if the file has command_permissions section
        if grep -q "command_permissions:" "$yaml_file"; then
            log "  Found command_permissions section"
        else
            log "  No command_permissions section found"
            continue
        fi
        
        # Extract allow permissions
        log "  Extracting allow permissions..."
        extracted_count=0
        while IFS= read -r perm; do
            if [ -n "$perm" ]; then
                all_allow_perms+=("$perm")
                ((extracted_count++))
                log "    Added: $perm"
            fi
        done < <(extract_permissions_from_yaml "$yaml_file" "allow")
        log "  Extracted $extracted_count allow permissions"
        
        # Extract deny permissions
        log "  Extracting deny permissions..."
        extracted_count=0
        while IFS= read -r perm; do
            if [ -n "$perm" ]; then
                all_deny_perms+=("$perm")
                ((extracted_count++))
                log "    Added: $perm"
            fi
        done < <(extract_permissions_from_yaml "$yaml_file" "deny")
        log "  Extracted $extracted_count deny permissions"
    fi
done

# Deduplicate permissions - MUST preserve array elements with spaces
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

log "Copying claude-settings.json template..."
cp "$SETTINGS_TEMPLATE" "$TEMP_DIR/settings.json"

# Generate the workspace settings with dynamic permissions
log "Generating user-local-settings.json with dynamic permissions..."

# Function to escape JSON string
json_escape() {
    local str="$1"
    # Use jq if available for proper JSON escaping
    if command -v jq >/dev/null 2>&1; then
        echo -n "$str" | jq -Rs .
    else
        # Fallback: basic escaping
        str="${str//\\/\\\\}"
        str="${str//\"/\\\"}"
        str="${str//$'\n'/\\n}"
        str="${str//$'\r'/\\r}"
        str="${str//$'\t'/\\t}"
        echo "\"$str\""
    fi
}

# Create the JSON structure using jq
if command -v jq >/dev/null 2>&1; then
    log "Using jq to create proper JSON structure..."
    
    # Create a temporary file with the permissions as JSON arrays
    {
        echo '{'
        echo '  "permissions": {'
        
        # Allow permissions
        echo '    "allow": ['
        first=true
        for perm in "${all_allow_perms[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            printf "      %s" "$(json_escape "$perm")"
        done
        [ ${#all_allow_perms[@]} -gt 0 ] && echo
        echo '    ],'
        
        # Deny permissions
        echo '    "deny": ['
        first=true
        for perm in "${all_deny_perms[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            printf "      %s" "$(json_escape "$perm")"
        done
        [ ${#all_deny_perms[@]} -gt 0 ] && echo
        echo '    ]'
        
        echo '  }'
        echo '}'
    } | jq . > "$TEMP_DIR/user-local-settings.json"
    
else
    # Fallback without jq
    log "Creating JSON manually (jq not found)..."
    
    {
        echo '{'
        echo '  "permissions": {'
        echo '    "allow": ['
        
        # Add allow permissions
        first=true
        for perm in "${all_allow_perms[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            # Basic JSON escaping
            escaped_perm="${perm//\\/\\\\}"
            escaped_perm="${escaped_perm//\"/\\\"}"
            echo -n "      \"$escaped_perm\""
        done
        [ ${#all_allow_perms[@]} -gt 0 ] && echo
        echo '    ],'
        
        echo '    "deny": ['
        # Add deny permissions
        first=true
        for perm in "${all_deny_perms[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            # Basic JSON escaping
            escaped_perm="${perm//\\/\\\\}"
            escaped_perm="${escaped_perm//\"/\\\"}"
            echo -n "      \"$escaped_perm\""
        done
        [ ${#all_deny_perms[@]} -gt 0 ] && echo
        echo '    ]'
        echo '  }'
        echo '}'
    } > "$TEMP_DIR/user-local-settings.json"
fi

success "Generated user-local-settings.json with permissions"

# Verify the JSON is valid
if command -v jq >/dev/null 2>&1; then
    if jq . "$TEMP_DIR/user-local-settings.json" >/dev/null 2>&1; then
        success "JSON validation passed"
    else
        error "Generated JSON is invalid!"
    fi
fi

# Create a manifest of included files
cat > "$TEMP_DIR/MANIFEST.txt" << EOF
# Claude Code Autonomous Development System Manifest

## Core Files
- CLAUDE.md.template: Product Manager orchestration guide template
- claude-settings.json: Global settings (no hooks)
- user-local-settings.json: Workspace settings with dynamic permissions

## Commands ($(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | sed 's|.*/|  - |' | sort)

## Agents ($(ls -1 "$TEMP_DIR/agents/"*.md 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/agents/"*.md 2>/dev/null | sed 's|.*/|  - |' | sort)

## Utility Scripts ($(ls -1 "$TEMP_DIR/scripts/"*.sh 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/scripts/"*.sh 2>/dev/null | sed 's|.*/|  - |' | sort)

## Hooks ($(ls -1 "$TEMP_DIR/hooks/"*.sh 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/hooks/"*.sh 2>/dev/null | sed 's|.*/|  - |' | sort)

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
info "The system uses Team Topologies principles for realistic team modeling"
info "Product Manager runs in main thread for deterministic orchestration"
info "Kanban cards track work progress through JOURNAL.md"
info "Permissions have been dynamically generated from ${#SELECTED_YAML_FILES} components"
