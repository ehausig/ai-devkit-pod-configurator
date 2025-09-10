#!/bin/bash
# YAML Repository Pattern
# Provides a consistent interface for YAML operations across different yq implementations

# Global variable to store detected yq type
YQ_TYPE=""

# Detect which yq implementation is available
detect_yq_type() {
    if [[ -n "$YQ_TYPE" ]]; then
        # Already detected
        return 0
    fi
    
    local yq_path=$(command -v yq 2>/dev/null)
    if [[ -z "$yq_path" ]]; then
        echo "ERROR: yq not found in PATH" >&2
        return 1
    fi
    
    # Check if it's the Python (kislyuk) or Go (mikefarah) version
    if head -1 "$yq_path" 2>/dev/null | grep -q "python"; then
        YQ_TYPE="kislyuk"
    else
        # Assume mikefarah/yq (Go version) as it's binary
        YQ_TYPE="mikefarah"
    fi
    
    echo "INFO: Detected yq type: $YQ_TYPE" >&2
    return 0
}

# Read a value from YAML file
# Usage: yaml_read file.yaml "path.to.value"
yaml_read() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        return 1
    fi
    
    detect_yq_type || return 1
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        # kislyuk/yq uses jq syntax
        yq -r "$path" "$file" 2>/dev/null
    else
        # mikefarah/yq uses eval syntax
        yq eval "$path" "$file" 2>/dev/null
    fi
}

# Read array/list from YAML file
# Usage: yaml_read_array file.yaml "path.to.array"
yaml_read_array() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        return 1
    fi
    
    detect_yq_type || return 1
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        # kislyuk/yq - output as JSON array, then iterate
        yq -r "$path | .[]?" "$file" 2>/dev/null
    else
        # mikefarah/yq - use splat operator
        yq eval "$path | .[]" "$file" 2>/dev/null
    fi
}

# Check if a key exists in YAML
# Usage: yaml_has_key file.yaml "path.to.key"
yaml_has_key() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    detect_yq_type || return 1
    
    local result
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        result=$(yq -r "$path | type" "$file" 2>/dev/null)
    else
        result=$(yq eval "$path | type" "$file" 2>/dev/null)
    fi
    
    [[ -n "$result" ]] && [[ "$result" != "null" ]]
}

# Get array length
# Usage: yaml_array_length file.yaml "path.to.array"
yaml_array_length() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        echo "0"
        return 1
    fi
    
    detect_yq_type || return 1
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        yq -r "$path | length" "$file" 2>/dev/null || echo "0"
    else
        yq eval "$path | length" "$file" 2>/dev/null || echo "0"
    fi
}

# Select items matching a condition
# Usage: yaml_select file.yaml "path[]" "condition"
# Example: yaml_select config.yaml ".components[]" ".id == \"python-3-11\""
yaml_select() {
    local file="$1"
    local path="$2"
    local condition="$3"
    
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        return 1
    fi
    
    detect_yq_type || return 1
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        yq -r "$path | select($condition)" "$file" 2>/dev/null
    else
        yq eval "$path | select($condition)" "$file" 2>/dev/null
    fi
}

# Write/update a value in YAML file
# Usage: yaml_write file.yaml "path.to.value" "new value"
yaml_write() {
    local file="$1"
    local path="$2"
    local value="$3"
    
    detect_yq_type || return 1
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        # kislyuk/yq doesn't support in-place editing well
        # Create temp file and replace
        local temp_file="${file}.tmp"
        yq "$path = \"$value\"" "$file" > "$temp_file" 2>/dev/null
        mv "$temp_file" "$file"
    else
        # mikefarah/yq supports in-place editing
        yq eval -i "$path = \"$value\"" "$file" 2>/dev/null
    fi
}

# Merge two YAML files
# Usage: yaml_merge base.yaml override.yaml > merged.yaml
yaml_merge() {
    local base_file="$1"
    local override_file="$2"
    
    if [[ ! -f "$base_file" ]]; then
        echo "ERROR: Base file not found: $base_file" >&2
        return 1
    fi
    
    if [[ ! -f "$override_file" ]]; then
        echo "ERROR: Override file not found: $override_file" >&2
        return 1
    fi
    
    detect_yq_type || return 1
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        # kislyuk/yq uses jq-style merge
        yq -s ".[0] * .[1]" "$base_file" "$override_file" 2>/dev/null
    else
        # mikefarah/yq merge
        yq eval-all '. as $item ireduce ({}; . * $item)' "$base_file" "$override_file" 2>/dev/null
    fi
}

# Get all keys at a path
# Usage: yaml_keys file.yaml "path"
yaml_keys() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        return 1
    fi
    
    detect_yq_type || return 1
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        if [[ -z "$path" ]] || [[ "$path" == "." ]]; then
            yq -r "keys[]" "$file" 2>/dev/null
        else
            yq -r "$path | keys[]" "$file" 2>/dev/null
        fi
    else
        if [[ -z "$path" ]] || [[ "$path" == "." ]]; then
            yq eval "keys | .[]" "$file" 2>/dev/null
        else
            yq eval "$path | keys | .[]" "$file" 2>/dev/null
        fi
    fi
}

# Convert YAML to JSON
# Usage: yaml_to_json file.yaml
yaml_to_json() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        return 1
    fi
    
    detect_yq_type || return 1
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        # kislyuk/yq outputs JSON by default
        yq . "$file" 2>/dev/null
    else
        # mikefarah/yq needs explicit JSON output
        yq eval -o=json "$file" 2>/dev/null
    fi
}

# Parse YAML from stdin
# Usage: echo "key: value" | yaml_parse "path"
yaml_parse() {
    local path="${1:-.}"
    
    detect_yq_type || return 1
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        yq -r "$path" 2>/dev/null
    else
        yq eval "$path" - 2>/dev/null
    fi
}

# Get type of a value
# Usage: yaml_type file.yaml "path"
yaml_type() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        echo "null"
        return 1
    fi
    
    detect_yq_type || return 1
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        yq -r "$path | type" "$file" 2>/dev/null || echo "null"
    else
        yq eval "$path | type" "$file" 2>/dev/null || echo "null"
    fi
}

# Export functions for use by other scripts
export -f detect_yq_type 2>/dev/null || true
export -f yaml_read 2>/dev/null || true
export -f yaml_read_array 2>/dev/null || true
export -f yaml_has_key 2>/dev/null || true
export -f yaml_array_length 2>/dev/null || true
export -f yaml_select 2>/dev/null || true
export -f yaml_write 2>/dev/null || true
export -f yaml_merge 2>/dev/null || true
export -f yaml_keys 2>/dev/null || true
export -f yaml_to_json 2>/dev/null || true
export -f yaml_parse 2>/dev/null || true
export -f yaml_type 2>/dev/null || true