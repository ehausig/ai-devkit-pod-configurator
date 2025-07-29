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
USER_CLAUDE="$SCRIPT_DIR/claude-code/user-CLAUDE.md"
SETTINGS_TEMPLATE="$SCRIPT_DIR/claude-code/claude-settings.json.template"
WORKSPACE_SETTINGS_TEMPLATE="$SCRIPT_DIR/claude-code/claude-workspace-settings.json.template"

[[ ! -f "$USER_CLAUDE" ]] && error "user-CLAUDE.md not found in $SCRIPT_DIR/claude-code"
[[ ! -f "$SETTINGS_TEMPLATE" ]] && error "claude-settings.json.template not found in $SCRIPT_DIR/claude-code"
[[ ! -f "$WORKSPACE_SETTINGS_TEMPLATE" ]] && error "claude-workspace-settings.json.template not found in $SCRIPT_DIR/claude-code"

log "Setting up Claude Code autonomous development system with Team Topologies..."

# Create necessary directories
mkdir -p "$TEMP_DIR/commands"
mkdir -p "$TEMP_DIR/agents"
mkdir -p "$TEMP_DIR/scripts"

# Copy user documentation
log "Copying user documentation..."
cp "$USER_CLAUDE" "$TEMP_DIR/"
success "Copied user-CLAUDE.md"

# Copy settings template (no hooks)
log "Copying settings template..."
cp "$SETTINGS_TEMPLATE" "$TEMP_DIR/"
success "Copied claude-settings.json.template (no hooks configured)"

# Copy workspace settings template
log "Copying workspace settings template..."
cp "$WORKSPACE_SETTINGS_TEMPLATE" "$TEMP_DIR/"
success "Copied claude-workspace-settings.json.template"

# Copy commands
if [[ -d "$SCRIPT_DIR/claude-code/commands" ]]; then
    log "Copying autonomous development commands..."
    # Copy all needed commands
    for cmd in init-autonomous show-journal event-query kanban-status; do
        if [[ -f "$SCRIPT_DIR/claude-code/commands/${cmd}.md" ]]; then
            cp "$SCRIPT_DIR/claude-code/commands/${cmd}.md" "$TEMP_DIR/commands/"
        fi
    done
    success "Copied $(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | wc -l) commands"
fi

# Copy Team Topologies agents
if [[ -d "$SCRIPT_DIR/claude-code/agents" ]]; then
    log "Copying Team Topologies agent definitions..."
    
    # Stream-Aligned Team
    for agent in feature-developer qa-engineer; do
        [[ -f "$SCRIPT_DIR/claude-code/agents/${agent}.md" ]] && cp "$SCRIPT_DIR/claude-code/agents/${agent}.md" "$TEMP_DIR/agents/"
    done
    
    # Platform Team
    for agent in platform-engineer database-engineer; do
        [[ -f "$SCRIPT_DIR/claude-code/agents/${agent}.md" ]] && cp "$SCRIPT_DIR/claude-code/agents/${agent}.md" "$TEMP_DIR/agents/"
    done
    
    # Enabling Team
    for agent in api-designer security-specialist performance-engineer solution-architect data-architect cloud-architect; do
        [[ -f "$SCRIPT_DIR/claude-code/agents/${agent}.md" ]] && cp "$SCRIPT_DIR/claude-code/agents/${agent}.md" "$TEMP_DIR/agents/"
    done
    
    # Complicated Subsystem Team
    for agent in integration-specialist algorithm-developer; do
        [[ -f "$SCRIPT_DIR/claude-code/agents/${agent}.md" ]] && cp "$SCRIPT_DIR/claude-code/agents/${agent}.md" "$TEMP_DIR/agents/"
    done
    
    success "Copied $(ls -1 "$TEMP_DIR/agents/"*.md 2>/dev/null | wc -l) Team Topologies agents"
fi

# Copy utility scripts
if [[ -d "$SCRIPT_DIR/claude-code/scripts" ]]; then
    log "Copying utility scripts..."
    
    # Copy journal logging script
    if [[ -f "$SCRIPT_DIR/claude-code/scripts/journal-log.sh" ]]; then
        cp "$SCRIPT_DIR/claude-code/scripts/journal-log.sh" "$TEMP_DIR/scripts/"
        chmod +x "$TEMP_DIR/scripts/journal-log.sh"
    fi
    
    # Copy card ID generator
    if [[ -f "$SCRIPT_DIR/claude-code/scripts/generate-card-id.sh" ]]; then
        cp "$SCRIPT_DIR/claude-code/scripts/generate-card-id.sh" "$TEMP_DIR/scripts/"
        chmod +x "$TEMP_DIR/scripts/generate-card-id.sh"
    fi
    
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
    
    # Check if yq is available
    if command -v yq >/dev/null 2>&1; then
        # Use yq for proper YAML parsing
        yq eval ".command_permissions.${perm_type}[]" "$yaml_file" 2>/dev/null || true
    else
        # Fallback to manual parsing if yq is not available
        local in_permissions=false
        local in_target=false
        local indent_count=0
        local target_indent=0
        
        while IFS= read -r line; do
            # Check for command_permissions section
            if [[ "$line" =~ ^command_permissions:[[:space:]]*$ ]]; then
                in_permissions=true
                continue
            fi
            
            # Exit if we hit a top-level key
            if [[ "$in_permissions" == true ]] && [[ "$line" =~ ^[^[:space:]] ]]; then
                break
            fi
            
            # Check for our target section (allow/deny)
            if [[ "$in_permissions" == true ]] && [[ "$line" =~ ^([[:space:]]+)${perm_type}:[[:space:]]*$ ]]; then
                in_target=true
                # Count the indent level
                target_indent="${#BASH_REMATCH[1]}"
                continue
            fi
            
            # Exit target section if we hit another key at the same indent level
            if [[ "$in_target" == true ]]; then
                # Check if line starts with spaces
                if [[ "$line" =~ ^([[:space:]]+) ]]; then
                    current_indent="${#BASH_REMATCH[1]}"
                    # If we're back at the same level as allow/deny but it's not an array item
                    if [[ $current_indent -le $target_indent ]] && [[ ! "$line" =~ ^[[:space:]]+-[[:space:]] ]]; then
                        break
                    fi
                fi
            fi
            
            # Extract array items
            if [[ "$in_target" == true ]] && [[ "$line" =~ ^[[:space:]]+-[[:space:]](.*)$ ]]; then
                local perm="${BASH_REMATCH[1]}"
                # Remove quotes if present
                if [[ "$perm" =~ ^\"(.*)\"$ ]] || [[ "$perm" =~ ^\'(.*)\'$ ]]; then
                    perm="${BASH_REMATCH[1]}"
                fi
                # Output the permission if not empty
                [[ -n "$perm" ]] && echo "$perm"
            fi
        done < "$yaml_file"
    fi
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

# Generate the final settings.json (copy template as-is - no hooks)
log "Copying claude-settings.json template..."
cp "$SETTINGS_TEMPLATE" "$TEMP_DIR/claude-settings.json"
cp "$SETTINGS_TEMPLATE" "$TEMP_DIR/claude-settings.json.template"
success "Copied claude-settings.json (no hooks configured)"

# Generate the workspace settings with dynamic permissions
log "Generating claude-workspace-settings.json with dynamic permissions..."

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
    } | jq . > "$TEMP_DIR/claude-workspace-settings.json"
    
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
    } > "$TEMP_DIR/claude-workspace-settings.json"
fi

success "Generated claude-workspace-settings.json with permissions"

# Verify the JSON is valid
if command -v jq >/dev/null 2>&1; then
    if jq . "$TEMP_DIR/claude-workspace-settings.json" >/dev/null 2>&1; then
        success "JSON validation passed"
    else
        error "Generated JSON is invalid!"
    fi
fi

# Create a manifest of included files
cat > "$TEMP_DIR/MANIFEST.txt" << EOF
# Claude Code Autonomous Development System Manifest

## Core Files
- user-CLAUDE.md: Product Manager orchestration guide
- claude-settings.json: Global settings (no hooks)
- claude-workspace-settings.json: Workspace settings with dynamic permissions

## Commands ($(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | wc -l))
$(ls -1 "$TEMP_DIR/commands/"*.md 2>/dev/null | sed 's|.*/|  - |')

## Team Topologies Agents ($(ls -1 "$TEMP_DIR/agents/"*.md 2>/dev/null | wc -l))

### Stream-Aligned Team
- feature-developer.md: Implements features and business logic
- qa-engineer.md: Validates implementations

### Platform Team
- platform-engineer.md: Infrastructure and CI/CD
- database-engineer.md: Data models and schemas

### Enabling Team
- api-designer.md: API specifications
- security-specialist.md: Security reviews
- performance-engineer.md: Performance optimization
- solution-architect.md: High-level system architecture
- data-architect.md: Enterprise data architecture
- cloud-architect.md: Cloud infrastructure and migration

### Complicated Subsystem Team
- integration-specialist.md: Third-party integrations
- algorithm-developer.md: Complex algorithms

## System Overview
The autonomous development system uses:
1. Product Manager (main thread) as orchestrator
2. Team Topologies-based organization
3. Kanban card system for work tracking
4. JOURNAL.md for state persistence
5. Deterministic handoffs between teams
6. No reliance on hooks for orchestration

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
