#!/bin/bash
# Volume Mount Manager for Dynamic Component Configuration
# Manages dynamic volume mount generation for components

# Only set strict mode if not being sourced interactively
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi

# Collect volume mounts from a component
collect_component_mounts() {
    local component_dir="$1"
    local component_name="$2"
    local mount_file="$component_dir/ai-devkit/volume-mounts.yaml"
    
    if [[ ! -f "$mount_file" ]]; then
        return 0  # No mounts defined, not an error
    fi
    
    # Parse and return mount specifications
    yq -r ".mounts[]? | . + {component: \"$component_name\"}" "$mount_file" 2>/dev/null || {
        echo "WARNING: Failed to parse volume mounts for $component_name" >&2
        return 0
    }
}

# Generate Kubernetes volume mount specifications
generate_volume_mounts() {
    local component_dir="$1"
    local component_name="$2"
    local config_dir="$3"
    
    local mount_file="$component_dir/ai-devkit/volume-mounts.yaml"
    if [[ ! -f "$mount_file" ]]; then
        return 0
    fi
    
    # Get the number of mounts
    local mount_count=$(yq -r '.mounts | length' "$mount_file" 2>/dev/null)
    if [[ -z "$mount_count" ]] || [[ "$mount_count" == "null" ]] || [[ "$mount_count" == "0" ]]; then
        return 0
    fi
    
    # Generate mount specifications for each mount
    for (( i=0; i<mount_count; i++ )); do
        local name=$(yq -r ".mounts[$i].name" "$mount_file")
        local source=$(yq -r ".mounts[$i].source" "$mount_file")
        local target=$(yq -r ".mounts[$i].target" "$mount_file")
        local mount_type=$(yq -r ".mounts[$i].type // \"file\"" "$mount_file")
        local permissions=$(yq -r ".mounts[$i].permissions // \"\"" "$mount_file")
        
        # Output mount specification in format needed by deployment
        cat <<EOF
- name: "$name"
  source: "$config_dir/$source"
  target: "$target"
  type: "$mount_type"
  component: "$component_name"
  permissions: "$permissions"
EOF
    done
}

# Generate ConfigMap entries for component files
generate_configmap_entries() {
    local component_name="$1"
    local config_dir="$2"
    local component_dir="$3"
    
    local mount_file="$component_dir/ai-devkit/volume-mounts.yaml"
    if [[ ! -f "$mount_file" ]]; then
        return 0
    fi
    
    # Get the number of mounts
    local mount_count=$(yq -r '.mounts | length' "$mount_file" 2>/dev/null)
    if [[ -z "$mount_count" ]] || [[ "$mount_count" == "null" ]] || [[ "$mount_count" == "0" ]]; then
        return 0
    fi
    
    # Generate ConfigMap data entries
    for (( i=0; i<mount_count; i++ )); do
        local name=$(yq -r ".mounts[$i].name" "$mount_file")
        local source=$(yq -r ".mounts[$i].source" "$mount_file")
        local mount_type=$(yq -r ".mounts[$i].type // \"file\"" "$mount_file")
        
        if [[ "$mount_type" == "file" ]]; then
            local source_file="$config_dir/$source"
            if [[ -f "$source_file" ]]; then
                # Escape the name for ConfigMap key
                local key="${component_name}-${name}"
                key=$(echo "$key" | sed 's/[^a-zA-Z0-9._-]/-/g')
                
                echo "  $key: |"
                # Indent file contents for YAML
                sed 's/^/    /' "$source_file"
            fi
        elif [[ "$mount_type" == "directory" ]]; then
            # For directories, we need to handle multiple files
            local source_dir="$config_dir/$source"
            if [[ -d "$source_dir" ]]; then
                for file in "$source_dir"/*; do
                    if [[ -f "$file" ]]; then
                        local basename=$(basename "$file")
                        local key="${component_name}-${name}-${basename}"
                        key=$(echo "$key" | sed 's/[^a-zA-Z0-9._-]/-/g')
                        
                        echo "  $key: |"
                        sed 's/^/    /' "$file"
                    fi
                done
            fi
        fi
    done
}

# Generate deployment volume specifications
generate_deployment_volumes() {
    local all_mounts="$1"
    
    if [[ -z "$all_mounts" ]] || [[ "$all_mounts" == "[]" ]]; then
        return 0
    fi
    
    # Extract unique volume names and their permissions from YAML array items
    local volume_info=""
    if [[ "$all_mounts" == -* ]]; then
        # Process each unique volume name
        local volume_names=$(echo "$all_mounts" | grep "name:" | sed 's/.*name: *"\?\([^"]*\)"\?.*/\1/' | sort -u)
        
        while IFS= read -r volume_name; do
            if [[ -n "$volume_name" ]]; then
                # Find the permissions for this volume (take first occurrence)
                local permissions=""
                local mount_entry=$(echo "$all_mounts" | grep -A5 "name: *\"*$volume_name\"*" | head -6)
                if [[ -n "$mount_entry" ]]; then
                    permissions=$(echo "$mount_entry" | grep "permissions:" | head -1 | sed 's/.*permissions: *"\?\([^"]*\)"\?.*/\1/')
                fi
                
                # Default permissions based on target path if not specified
                if [[ -z "$permissions" ]] || [[ "$permissions" == '""' ]]; then
                    # Check if this is a test directory mount
                    local target=$(echo "$mount_entry" | grep "target:" | head -1 | sed 's/.*target: *"\?\([^"]*\)"\?.*/\1/')
                    if [[ "$target" =~ \.ai-devkit/tests/ ]]; then
                        permissions="0755"
                    else
                        permissions="0644"
                    fi
                fi
                
                # Convert permissions to decimal for Kubernetes (it expects decimal, not octal string)
                local mode_decimal=420  # Default 0644 in decimal
                if [[ "$permissions" == "0755" ]]; then
                    mode_decimal=493  # 0755 in decimal
                elif [[ "$permissions" == "0644" ]]; then
                    mode_decimal=420  # 0644 in decimal
                elif [[ "$permissions" == "0600" ]]; then
                    mode_decimal=384  # 0600 in decimal
                fi
                
                cat <<EOF
      - name: $volume_name
        configMap:
          name: component-configs
          defaultMode: $mode_decimal
EOF
            fi
        done <<< "$volume_names"
    fi
}

# Generate deployment volume mount specifications
generate_deployment_volume_mounts() {
    local all_mounts="$1"
    
    if [[ -z "$all_mounts" ]]; then
        return 0
    fi
    
    # For now, if the mounts file is empty or contains just [], skip
    if [[ "$all_mounts" == "[]" ]]; then
        return 0
    fi
    
    # If it starts with -, it's YAML array items - process line by line
    if [[ "$all_mounts" == -* ]]; then
        # Simply parse each YAML mount item
        local current_mount=""
        while IFS= read -r line; do
            if [[ "$line" == "- name:"* ]]; then
                # Start of a new mount, process previous if exists
                if [[ -n "$current_mount" ]]; then
                    process_single_mount "$current_mount"
                fi
                current_mount="$line"
            elif [[ -n "$current_mount" ]]; then
                current_mount="$current_mount"$'\n'"$line"
            fi
        done <<< "$all_mounts"
        
        # Process last mount
        if [[ -n "$current_mount" ]]; then
            process_single_mount "$current_mount"
        fi
    fi
}

# Helper to process a single mount entry
process_single_mount() {
    local mount_yaml="$1"
    
    # Extract fields using simple grep/sed since we know the structure
    local name=$(echo "$mount_yaml" | grep "name:" | sed 's/.*name: *"\?\([^"]*\)"\?.*/\1/')
    local target=$(echo "$mount_yaml" | grep "target:" | sed 's/.*target: *"\?\([^"]*\)"\?.*/\1/')
    local mount_type=$(echo "$mount_yaml" | grep "type:" | sed 's/.*type: *"\?\([^"]*\)"\?.*/\1/')
    local permissions=$(echo "$mount_yaml" | grep "permissions:" | sed 's/.*permissions: *"\?\([^"]*\)"\?.*/\1/')
    
    # Default type to file if not specified
    if [[ -z "$mount_type" ]]; then
        mount_type="file"
    fi
    
    # Set executable permissions for test directories
    if [[ "$target" =~ \.ai-devkit/tests/ ]] && [[ -z "$permissions" ]]; then
        permissions="0755"
    fi
    
    cat <<EOF
        - name: $name
          mountPath: $target
EOF
    
    if [[ "$mount_type" == "file" ]]; then
        echo "          subPath: $(basename $target)"
    fi
    
    # Note: defaultMode is not valid on volumeMounts, only on volume definitions
    # Permissions should be set in the volume definition, not the mount
}

# Export functions
export -f collect_component_mounts
export -f generate_volume_mounts
export -f generate_configmap_entries
export -f generate_deployment_volumes
export -f generate_deployment_volume_mounts
export -f process_single_mount