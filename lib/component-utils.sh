#!/bin/bash
# Component Utils Library
# Provides common functions for component discovery and management

# Source yaml-repository for consistent YAML operations
source "$(dirname "${BASH_SOURCE[0]}")/yaml-repository.sh"

# Global variables
COMPONENTS_BASE_DIR="${COMPONENTS_DIR:-components}"

# Find all component YAML files
# Usage: find_component_yamls [category]
find_component_yamls() {
    local category="${1:-}"
    local search_dir="$COMPONENTS_BASE_DIR"
    
    if [[ -n "$category" ]]; then
        search_dir="$COMPONENTS_BASE_DIR/$category"
    fi
    
    if [[ ! -d "$search_dir" ]]; then
        return 1
    fi
    
    # Find all .yaml files, excluding file-mappings.yaml and other special files
    find "$search_dir" -name "*.yaml" -type f 2>/dev/null | \
        grep -v "/ai-devkit/" | \
        grep -v "file-mappings.yaml" | \
        grep -v "volume-mounts.yaml" | \
        sort
}

# Get component directory from YAML file path
# Usage: get_component_dir yaml_file
get_component_dir() {
    local yaml_file="$1"
    dirname "$yaml_file"
}

# Get component ID from YAML file
# Usage: get_component_id yaml_file
get_component_id() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        echo "ERROR: Component file not found: $yaml_file" >&2
        return 1
    fi
    
    yaml_read "$yaml_file" ".id"
}

# Get component display name
# Usage: get_component_name yaml_file
get_component_name() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        echo "ERROR: Component file not found: $yaml_file" >&2
        return 1
    fi
    
    yaml_read "$yaml_file" ".name"
}

# Get component description
# Usage: get_component_description yaml_file
get_component_description() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        echo "ERROR: Component file not found: $yaml_file" >&2
        return 1
    fi
    
    yaml_read "$yaml_file" ".description"
}

# Get component version
# Usage: get_component_version yaml_file
get_component_version() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        return 1
    fi
    
    yaml_read "$yaml_file" ".version"
}

# List all categories
# Usage: list_categories
list_categories() {
    if [[ ! -d "$COMPONENTS_BASE_DIR" ]]; then
        return 1
    fi
    
    for dir in "$COMPONENTS_BASE_DIR"/*; do
        [[ -d "$dir" ]] || continue
        basename "$dir"
    done | sort
}

# Get category metadata
# Usage: get_category_metadata category
get_category_metadata() {
    local category="$1"
    local category_yaml="$COMPONENTS_BASE_DIR/$category/category.yaml"
    
    if [[ -f "$category_yaml" ]]; then
        echo "name:$(yaml_read "$category_yaml" ".name // \"$category\"")"
        echo "description:$(yaml_read "$category_yaml" ".description // \"\"")"
        echo "order:$(yaml_read "$category_yaml" ".order // 999")"
    else
        echo "name:$category"
        echo "description:"
        echo "order:999"
    fi
}

# Check if component has tests
# Usage: has_component_tests component_dir
has_component_tests() {
    local component_dir="$1"
    local test_dir="$component_dir/ai-devkit/tests"
    
    [[ -d "$test_dir" ]] && ls "$test_dir"/*.sh 2>/dev/null | grep -q .
}

# Get component test files
# Usage: get_component_tests component_dir
get_component_tests() {
    local component_dir="$1"
    local test_dir="$component_dir/ai-devkit/tests"
    
    if [[ -d "$test_dir" ]]; then
        find "$test_dir" -name "*.sh" -type f 2>/dev/null | sort
    fi
}

# Check if component has file mappings
# Usage: has_file_mappings component_dir
has_file_mappings() {
    local component_dir="$1"
    local mappings_file="$component_dir/ai-devkit/file-mappings.yaml"
    
    [[ -f "$mappings_file" ]] && [[ -s "$mappings_file" ]]
}

# Get component repositories
# Usage: get_component_repositories yaml_file
get_component_repositories() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        return 1
    fi
    
    yaml_read_array "$yaml_file" ".repositories"
}

# Check component dependencies
# Usage: check_component_dependencies yaml_file
check_component_dependencies() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        return 1
    fi
    
    local deps=$(yaml_read_array "$yaml_file" ".dependencies")
    if [[ -n "$deps" ]]; then
        echo "$deps"
        return 0
    fi
    return 1
}

# Check for component conflicts
# Usage: check_component_conflicts yaml_file
check_component_conflicts() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        return 1
    fi
    
    local conflicts=$(yaml_read_array "$yaml_file" ".conflicts")
    if [[ -n "$conflicts" ]]; then
        echo "$conflicts"
        return 0
    fi
    return 1
}

# Validate component structure
# Usage: validate_component component_dir
validate_component() {
    local component_dir="$1"
    local errors=()
    
    # Check for component YAML
    local yaml_file=$(find "$component_dir" -maxdepth 1 -name "*.yaml" -type f | head -1)
    if [[ -z "$yaml_file" ]]; then
        errors+=("No component YAML file found")
    else
        # Check required fields
        local id=$(get_component_id "$yaml_file")
        local name=$(get_component_name "$yaml_file")
        
        [[ -z "$id" ]] && errors+=("Missing component ID")
        [[ -z "$name" ]] && errors+=("Missing component name")
    fi
    
    # Report errors
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "Validation errors for $component_dir:" >&2
        for error in "${errors[@]}"; do
            echo "  - $error" >&2
        done
        return 1
    fi
    
    return 0
}

# Get component's sanitized ID for Kubernetes resources
# Usage: sanitize_component_id component_id
sanitize_component_id() {
    local component_id="$1"
    echo "$component_id" | tr '[:upper:]' '[:lower:]' | tr '_' '-'
}

# Get all components in a category
# Usage: get_category_components category
get_category_components() {
    local category="$1"
    find_component_yamls "$category"
}

# Count total components
# Usage: count_components [category]
count_components() {
    local category="${1:-}"
    find_component_yamls "$category" | wc -l
}

# Export functions for use by other scripts
export -f find_component_yamls 2>/dev/null || true
export -f get_component_dir 2>/dev/null || true
export -f get_component_id 2>/dev/null || true
export -f get_component_name 2>/dev/null || true
export -f get_component_description 2>/dev/null || true
export -f get_component_version 2>/dev/null || true
export -f list_categories 2>/dev/null || true
export -f get_category_metadata 2>/dev/null || true
export -f has_component_tests 2>/dev/null || true
export -f get_component_tests 2>/dev/null || true
export -f has_file_mappings 2>/dev/null || true
export -f get_component_repositories 2>/dev/null || true
export -f check_component_dependencies 2>/dev/null || true
export -f check_component_conflicts 2>/dev/null || true
export -f validate_component 2>/dev/null || true
export -f sanitize_component_id 2>/dev/null || true
export -f get_category_components 2>/dev/null || true
export -f count_components 2>/dev/null || true