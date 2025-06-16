#!/bin/bash
# Claude Code pre-build script
# Generates CLAUDE.md and prepares claude-settings.json.template

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

# Verify template files exist
CLAUDE_TEMPLATE="$SCRIPT_DIR/CLAUDE.md.template"
SETTINGS_TEMPLATE="$SCRIPT_DIR/claude-settings.json.template"

[[ ! -f "$CLAUDE_TEMPLATE" ]] && error "CLAUDE.md.template not found in $SCRIPT_DIR"
[[ ! -f "$SETTINGS_TEMPLATE" ]] && error "claude-settings.json.template not found in $SCRIPT_DIR"

log "Generating CLAUDE.md for selected components..."

# Copy template up to marker
CLAUDE_OUTPUT="$TEMP_DIR/CLAUDE.md"
sed '/<!-- ENVIRONMENT_TOOLS_MARKER -->/q' "$CLAUDE_TEMPLATE" > "$CLAUDE_OUTPUT"

# Parse YAML file (simple parser using sed/awk)
parse_yaml() {
    local file=$1
    local prefix=$2
    
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" $file |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'", vn, $2, $3);
        }
    }'
}

# Extract memory content from YAML file
extract_memory_content() {
    local yaml_file=$1
    local in_memory_content=false
    local memory_content=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^memory_content:[[:space:]]*\|[[:space:]]*$ ]]; then
            in_memory_content=true
            continue
        fi
        
        if [[ $in_memory_content == true ]] && [[ "$line" =~ ^[a-zA-Z_]+: ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            in_memory_content=false
            break
        fi
        
        if [[ $in_memory_content == true ]]; then
            if [[ "$line" =~ ^"  " ]]; then
                memory_content+="${line:2}"$'\n'
            elif [[ -z "$line" ]]; then
                memory_content+=$'\n'
            fi
        fi
    done < "$yaml_file"
    
    memory_content=$(echo -n "$memory_content" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
    echo "$memory_content"
}

# Get category display name from .category.yaml
get_category_display_name() {
    local category_dir=$1
    local display_name=$(basename "$category_dir")
    
    if [[ -f "$category_dir/.category.yaml" ]]; then
        eval $(parse_yaml "$category_dir/.category.yaml" "cat_")
        [[ -n "$cat_display_name" ]] && display_name="$cat_display_name"
    fi
    
    echo "$display_name"
}

# Generate tool list
echo "" >> "$CLAUDE_OUTPUT"
echo "## Installed Development Environment" >> "$CLAUDE_OUTPUT"
echo "" >> "$CLAUDE_OUTPUT"
echo "This container includes the following tools and languages:" >> "$CLAUDE_OUTPUT"
echo "" >> "$CLAUDE_OUTPUT"

# Base tools (always present)
echo "### Base Tools" >> "$CLAUDE_OUTPUT"
echo "- Git" >> "$CLAUDE_OUTPUT"
echo "- GitHub CLI (gh)" >> "$CLAUDE_OUTPUT"

# Add memory content for base tools
echo "" >> "$CLAUDE_OUTPUT"
echo "#### Base Development Tools" >> "$CLAUDE_OUTPUT"
echo "" >> "$CLAUDE_OUTPUT"
echo "**Git & GitHub**:" >> "$CLAUDE_OUTPUT"
echo "- Clone repo: \`git clone https://github.com/user/repo.git\`" >> "$CLAUDE_OUTPUT"
echo "- GitHub CLI: \`gh repo create\`, \`gh pr create\`" >> "$CLAUDE_OUTPUT"
echo "- Git is pre-configured if you used host configuration" >> "$CLAUDE_OUTPUT"

# Process selected components by category
# Convert space-separated lists to arrays
IFS=' ' read -ra yaml_files_array <<< "$SELECTED_YAML_FILES"
IFS=' ' read -ra names_array <<< "$SELECTED_NAMES"

# Simple arrays to track categories and components
component_count=0
categories_seen=""

# First pass - collect and display components
for i in "${!yaml_files_array[@]}"; do
    yaml_file="${yaml_files_array[$i]}"
    name="${names_array[$i]}"
    
    # Extract category from path
    category=$(dirname "$yaml_file" | xargs basename)
    
    # Check if we've seen this category before
    if [[ ! "$categories_seen" =~ "$category" ]]; then
        categories_seen="$categories_seen $category"
        
        # Get display name for category
        category_dir=$(dirname "$yaml_file")
        display_name=$(get_category_display_name "$category_dir")
        
        echo "" >> "$CLAUDE_OUTPUT"
        echo "### $display_name" >> "$CLAUDE_OUTPUT"
    fi
    
    echo "- $name" >> "$CLAUDE_OUTPUT"
    ((component_count++))
done

# Add Tool-Specific Guidelines section with memory content
echo "" >> "$CLAUDE_OUTPUT"
echo "## Tool-Specific Guidelines" >> "$CLAUDE_OUTPUT"

# Extract and append memory content for each selected component
memory_content_added=false

for i in "${!yaml_files_array[@]}"; do
    yaml_file="${yaml_files_array[$i]}"
    component_name="${names_array[$i]}"
    
    info "Extracting memory content from $component_name..."
    
    memory_content=$(extract_memory_content "$yaml_file")
    if [[ -n "$memory_content" ]]; then
        if [[ $memory_content_added == true ]]; then
            echo "" >> "$CLAUDE_OUTPUT"
        fi
        echo "$memory_content" >> "$CLAUDE_OUTPUT"
        memory_content_added=true
        success "Added memory content for $component_name"
    else
        info "No memory content found for $component_name"
    fi
done

success "Generated CLAUDE.md with environment information"

# Copy settings template
log "Copying claude-settings.json.template..."
cp "$SETTINGS_TEMPLATE" "$TEMP_DIR/"
success "Copied claude-settings.json.template"

log "Claude Code pre-build completed successfully"
