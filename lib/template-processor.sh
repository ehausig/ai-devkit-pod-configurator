#!/bin/bash
# Template Processing Engine for Component Configuration
# This replaces the hard-coded component-config-generator.sh

set -euo pipefail

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config-reader.sh"
source "$SCRIPT_DIR/repository-loader.sh"
source "$SCRIPT_DIR/credential-manager.sh"

# Process a Jinja2 template with provided data
process_template() {
    local template_file="$1"
    local data_json="$2"
    local output_file="$3"
    
    if [[ ! -f "$template_file" ]]; then
        echo "ERROR: Template file not found: $template_file" >&2
        return 1
    fi
    
    # Create output directory if needed
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"
    
    # Use Python for Jinja2 processing (available in all our containers)
    python3 -c "
import json
import sys
from jinja2 import Template, Environment, FileSystemLoader
import os

# Load template
template_dir = os.path.dirname('$template_file')
template_name = os.path.basename('$template_file')
env = Environment(loader=FileSystemLoader(template_dir))
template = env.get_template(template_name)

# Load data
data = json.loads('''$data_json''')

# Add helper filters
def urlparse(url, part='hostname'):
    from urllib.parse import urlparse as parse
    parsed = parse(url)
    return getattr(parsed, part)

env.filters['urlparse'] = urlparse

# Render template
output = template.render(**data)

# Write output
with open('$output_file', 'w') as f:
    f.write(output)
" || {
        echo "ERROR: Failed to process template $template_file" >&2
        return 1
    }
    
    echo "Generated: $output_file"
    return 0
}

# Discover component configuration metadata
discover_component_config() {
    local component_dir="$1"
    local config_file="$component_dir/ai-devkit/config.yaml"
    
    if [[ ! -f "$config_file" ]]; then
        return 0  # No config, not an error
    fi
    
    yq -r '.' "$config_file" 2>/dev/null || {
        echo "ERROR: Failed to parse $config_file" >&2
        return 1
    }
}

# Generate configuration for a component
generate_component_configuration() {
    local component_dir="$1"
    local component_id="$2"
    local output_dir="$3"
    
    echo "Processing component: $component_id" >&2
    
    # Check for component configuration
    local config_file="$component_dir/ai-devkit/config.yaml"
    if [[ ! -f "$config_file" ]]; then
        echo "No configuration metadata for $component_id, skipping" >&2
        return 0
    fi
    
    # Load component configuration metadata
    local config=$(discover_component_config "$component_dir")
    if [[ -z "$config" ]]; then
        return 0
    fi
    
    # Get repository format
    local format=$(echo "$config" | yq -r '.configuration.format // ""')
    if [[ -z "$format" ]] || [[ "$format" == "null" ]]; then
        echo "No repository format for $component_id, skipping" >&2
        return 0
    fi
    
    # Load repositories for this component
    local repos_json=$(resolve_repositories "$component_id")
    
    # Process each template
    local template_count=$(echo "$config" | yq -r '.configuration.templates | length')
    if [[ "$template_count" != "null" ]] && [[ "$template_count" != "0" ]]; then
        for (( i=0; i<template_count; i++ )); do
            local source=$(echo "$config" | yq -r ".configuration.templates[$i].source")
            local output=$(echo "$config" | yq -r ".configuration.templates[$i].output")
            
            if [[ "$source" != "null" ]] && [[ "$output" != "null" ]]; then
                local template_path="$component_dir/ai-devkit/$source"
                local output_path="$output_dir/$output"
                
                # Prepare template data
                local template_data=$(cat <<EOF
{
    "repositories": $repos_json,
    "component_id": "$component_id",
    "format": "$format"
}
EOF
                )
                
                process_template "$template_path" "$template_data" "$output_path"
            fi
        done
    fi
    
    # Process environment variables if specified
    local env_count=$(echo "$config" | yq -r '.configuration.environment | length // 0')
    if [[ "$env_count" != "null" ]] && [[ "$env_count" != "0" ]]; then
        for (( i=0; i<env_count; i++ )); do
            local env_source=$(echo "$config" | yq -r ".configuration.environment[$i].source // \"\"")
            local env_output=$(echo "$config" | yq -r ".configuration.environment[$i].output // \"\"")
            
            if [[ -n "$env_source" ]] && [[ "$env_source" != "null" ]] && [[ -n "$env_output" ]] && [[ "$env_output" != "null" ]]; then
                local env_file="$component_dir/ai-devkit/$env_source"
                if [[ -f "$env_file" ]]; then
                    cp "$env_file" "$output_dir/$env_output"
                    echo "Generated: $output_dir/$env_output"
                fi
            fi
        done
    fi
    
    return 0
}

# Export functions for use by other scripts
export -f process_template
export -f discover_component_config
export -f generate_component_configuration