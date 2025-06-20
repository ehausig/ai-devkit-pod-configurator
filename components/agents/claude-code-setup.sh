#!/bin/bash
# Claude Code pre-build script
# Generates project CLAUDE.md and handles file copying

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

# Verify files exist
USER_CLAUDE="$SCRIPT_DIR/user-CLAUDE.md"
SETTINGS_TEMPLATE="$SCRIPT_DIR/claude-settings.json.template"

[[ ! -f "$USER_CLAUDE" ]] && error "user-CLAUDE.md not found in $SCRIPT_DIR"
[[ ! -f "$SETTINGS_TEMPLATE" ]] && error "claude-settings.json.template not found in $SCRIPT_DIR"

log "Generating project CLAUDE.md for selected components..."

# Create project CLAUDE.md
CLAUDE_OUTPUT="$TEMP_DIR/project-CLAUDE.md"
cat > "$CLAUDE_OUTPUT" << 'EOF'
# Additional Instructions

This workspace includes the following development tools:

EOF

# Get category display name from .category.yaml
get_category_display_name() {
    local category_dir=$1
    local display_name=$(basename "$category_dir")
    
    if [[ -f "$category_dir/.category.yaml" ]]; then
        # Extract display_name from .category.yaml
        local line
        while IFS= read -r line; do
            if [[ "$line" =~ ^display_name:[[:space:]]*(.+)$ ]]; then
                display_name="${BASH_REMATCH[1]}"
                # Remove quotes if present
                display_name="${display_name#\"}"
                display_name="${display_name%\"}"
                display_name="${display_name#\'}"
                display_name="${display_name%\'}"
                break
            fi
        done < "$category_dir/.category.yaml"
    fi
    
    echo "$display_name"
}

# Create arrays to store component data organized by category
declare -A category_components  # category -> list of "name|filename" entries
declare -A category_display_names
declare -a category_order

# Process each YAML file
for yaml_file in $SELECTED_YAML_FILES; do
    info "Processing: $yaml_file"
    
    # Extract component name from YAML file
    comp_name=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^name:[[:space:]]*(.+)$ ]]; then
            comp_name="${BASH_REMATCH[1]}"
            # Remove quotes if present
            comp_name="${comp_name#\"}"
            comp_name="${comp_name%\"}"
            comp_name="${comp_name#\'}"
            comp_name="${comp_name%\'}"
            break
        fi
    done < "$yaml_file"
    
    # Extract category from path
    # For path like "components/agents/claude-code.yaml", extract "agents"
    category=""
    if [[ "$yaml_file" =~ components/([^/]+)/ ]]; then
        category="${BASH_REMATCH[1]}"
    else
        # Fallback: use parent directory
        category=$(basename $(dirname "$yaml_file"))
    fi
    
    info "  Component: $comp_name"
    info "  Category: $category"
    
    # Get markdown filename
    yaml_basename=$(basename "$yaml_file" .yaml)
    md_filename="${yaml_basename}.md"
    
    # Initialize category if this is the first component in this category
    if [[ ! " ${category_order[@]} " =~ " ${category} " ]]; then
        category_order+=("$category")
        
        # Get display name for category
        local category_dir
        if [[ "$yaml_file" =~ ^(.*components/${category})/ ]]; then
            category_dir="${BASH_REMATCH[1]}"
        else
            category_dir=$(dirname "$yaml_file")
        fi
        
        category_display_names[$category]=$(get_category_display_name "$category_dir")
        info "  Category display name: ${category_display_names[$category]}"
    fi
    
    # Add component to its category
    if [[ -n "${category_components[$category]}" ]]; then
        category_components[$category]="${category_components[$category]}|${comp_name}:${md_filename}"
    else
        category_components[$category]="${comp_name}:${md_filename}"
    fi
    
    # Copy markdown file if it exists
    md_source="$(dirname "$yaml_file")/${md_filename}"
    if [[ -f "$md_source" ]]; then
        cp "$md_source" "$TEMP_DIR/${md_filename}"
        success "  Copied ${md_filename}"
    else
        log "  Warning: ${md_filename} not found for $comp_name"
    fi
done

# Write categories and components to CLAUDE.md
for category in "${category_order[@]}"; do
    display_name="${category_display_names[$category]}"
    
    echo "## $display_name" >> "$CLAUDE_OUTPUT"
    
    # Split components and write them
    IFS='|' read -ra components <<< "${category_components[$category]}"
    for component in "${components[@]}"; do
        # Split name:filename
        IFS=':' read -r comp_name md_filename <<< "$component"
        echo "- $comp_name @~/workspace/.claude/${md_filename}" >> "$CLAUDE_OUTPUT"
    done
    
    echo "" >> "$CLAUDE_OUTPUT"
done

success "Generated project CLAUDE.md with import references"

# Copy user-CLAUDE.md
log "Copying user-CLAUDE.md..."
cp "$USER_CLAUDE" "$TEMP_DIR/"
success "Copied user-CLAUDE.md"

# Copy settings template
log "Copying claude-settings.json.template..."
cp "$SETTINGS_TEMPLATE" "$TEMP_DIR/"
success "Copied claude-settings.json.template"

# Copy claude-code.md if it exists
if [[ -f "$SCRIPT_DIR/claude-code.md" ]]; then
    cp "$SCRIPT_DIR/claude-code.md" "$TEMP_DIR/"
    success "Copied claude-code.md"
fi

log "Claude Code pre-build completed successfully"
