#!/bin/bash
# Volume Mount Manager for Dynamic Component Configuration
# Manages dynamic volume mount generation for components

set -euo pipefail

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
    
    local mounts=$(collect_component_mounts "$component_dir" "$component_name")
    if [[ -z "$mounts" ]]; then
        return 0
    fi
    
    # Generate mount specifications for each mount
    echo "$mounts" | while IFS= read -r mount; do
        local name=$(echo "$mount" | yq -r '.name')
        local source=$(echo "$mount" | yq -r '.source')
        local target=$(echo "$mount" | yq -r '.target')
        local mount_type=$(echo "$mount" | yq -r '.type // "file"')
        local permissions=$(echo "$mount" | yq -r '.permissions // ""')
        
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
    
    local mounts=$(yq -r '.mounts[]?' "$mount_file" 2>/dev/null)
    if [[ -z "$mounts" ]]; then
        return 0
    fi
    
    # Generate ConfigMap data entries
    echo "$mounts" | while IFS= read -r mount; do
        local name=$(echo "$mount" | yq -r '.name')
        local source=$(echo "$mount" | yq -r '.source')
        local mount_type=$(echo "$mount" | yq -r '.type // "file"')
        
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
    
    if [[ -z "$all_mounts" ]]; then
        return 0
    fi
    
    # Generate unique volume definitions
    echo "$all_mounts" | yq -r '.name' | sort -u | while IFS= read -r volume_name; do
        cat <<EOF
      - name: $volume_name
        configMap:
          name: component-configs
          defaultMode: 0644
EOF
    done
}

# Generate deployment volume mount specifications
generate_deployment_volume_mounts() {
    local all_mounts="$1"
    
    if [[ -z "$all_mounts" ]]; then
        return 0
    fi
    
    # Generate volume mount definitions
    echo "$all_mounts" | while IFS= read -r mount; do
        local name=$(echo "$mount" | yq -r '.name')
        local target=$(echo "$mount" | yq -r '.target')
        local mount_type=$(echo "$mount" | yq -r '.type // "file"')
        local permissions=$(echo "$mount" | yq -r '.permissions // ""')
        
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
        
        if [[ -n "$permissions" ]] && [[ "$permissions" != "null" ]]; then
            echo "          defaultMode: $permissions"
        fi
    done
}

# Export functions
export -f collect_component_mounts
export -f generate_volume_mounts
export -f generate_configmap_entries
export -f generate_deployment_volumes
export -f generate_deployment_volume_mounts