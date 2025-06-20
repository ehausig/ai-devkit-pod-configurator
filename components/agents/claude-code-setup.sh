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

# Create temporary files to store category data
TEMP_CATEGORIES="$TEMP_DIR/.categories.tmp"
TEMP_COMPONENTS="$TEMP_DIR/.components.tmp"

# Clear temp files
> "$TEMP_CATEGORIES"
> "$TEMP_COMPONENTS"

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
    # The path should be like "components/CATEGORY/file.yaml"
    category=""
    if [[ "$yaml_file" =~ components/([^/]+)/[^/]+\.yaml$ ]]; then
        category="${BASH_REMATCH[1]}"
    else
        # Last resort: parent directory
        category=$(basename "$(dirname "$yaml_file")")
    fi
    
    info "  Component: $comp_name"
    info "  Category: $category"
    
    # Get markdown filename
    yaml_basename=$(basename "$yaml_file" .yaml)
    md_filename="${yaml_basename}.md"
    
    # Check if this category is already recorded
    if ! grep -q "^${category}|" "$TEMP_CATEGORIES"; then
        # Find the category directory to get display name
        category_dir=""
        if [[ "$yaml_file" =~ ^(.*/components/$category)/ ]]; then
            category_dir="${BASH_REMATCH[1]}"
        elif [[ -d "components/$category" ]]; then
            category_dir="components/$category"
        else
            category_dir=$(dirname "$yaml_file")
        fi
        
        display_name=$(get_category_display_name "$category_dir")
        info "  Category display name: $display_name"
        
        # Record category and display name
        echo "${category}|${display_name}" >> "$TEMP_CATEGORIES"
    fi
    
    # Check if markdown file exists before recording component
    md_source="$(dirname "$yaml_file")/${md_filename}"
    if [[ -f "$md_source" ]]; then
        # Only record component if markdown file exists
        echo "${category}|${comp_name}|${md_filename}" >> "$TEMP_COMPONENTS"
        
        # Copy the markdown file
        cp "$md_source" "$TEMP_DIR/${md_filename}"
        success "  Copied ${md_filename}"
    else
        info "  No ${md_filename} found - skipping component documentation"
    fi
done

# Debug: Show collected data
info "Categories collected:"
cat "$TEMP_CATEGORIES"
info "Components collected:"
cat "$TEMP_COMPONENTS"

# Write categories and components to CLAUDE.md
while IFS='|' read -r category display_name; do
    [[ -z "$category" ]] && continue
    
    # Check if this category has any components with markdown files
    category_has_components=false
    while IFS='|' read -r comp_category comp_name md_filename; do
        if [[ "$comp_category" == "$category" ]]; then
            category_has_components=true
            break
        fi
    done < "$TEMP_COMPONENTS"
    
    # Only write category header if it has components
    if [[ "$category_has_components" == "true" ]]; then
        echo "## $display_name" >> "$CLAUDE_OUTPUT"
        
        # Find all components for this category
        while IFS='|' read -r comp_category comp_name md_filename; do
            if [[ "$comp_category" == "$category" ]]; then
                echo "- $comp_name @~/workspace/.claude/${md_filename}" >> "$CLAUDE_OUTPUT"
            fi
        done < "$TEMP_COMPONENTS"
        
        echo "" >> "$CLAUDE_OUTPUT"
    fi
done < "$TEMP_CATEGORIES"

# Clean up temp files
rm -f "$TEMP_CATEGORIES" "$TEMP_COMPONENTS"

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
