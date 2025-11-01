#!/bin/bash
# Config reader library for the new components array format with credentials

# Function to read component repositories from config
# Uses the new format: components[].id
read_component_repos() {
    local component_id="$1"
    local config_file="${2:-$HOME/.ai-devkit/config.yaml}"
    
    # Read from components array format
    local repos=$(yq -r ".components[] | select(.id == \"$component_id\") | .repositories // []" "$config_file" 2>/dev/null)
    
    echo "$repos"
}

# Function to check if component should include default repos
read_include_defaults() {
    local component_id="$1"
    local config_file="${2:-$HOME/.ai-devkit/config.yaml}"
    
    # Read include_default_repos flag (default: true)
    local include=$(yq -r ".components[] | select(.id == \"$component_id\") | .include_default_repos // \"true\"" "$config_file" 2>/dev/null)
    
    if [[ -z "$include" ]] || [[ "$include" == "null" ]]; then
        echo "true"
    else
        echo "$include"
    fi
}

# Function to read credentials array
read_credentials() {
    local config_file="${1:-$HOME/.ai-devkit/config.yaml}"
    
    # Read all credentials
    yq -r '.credentials // []' "$config_file" 2>/dev/null
}

# Function to get specific credential by ID
read_credential() {
    local cred_id="$1"
    local config_file="${2:-$HOME/.ai-devkit/config.yaml}"
    
    # Read specific credential
    yq -r ".credentials[] | select(.id == \"$cred_id\") // {}" "$config_file" 2>/dev/null
}

# Function to get primary repository URL for a component
get_primary_repo_url() {
    local component_id="$1"
    local config_file="${2:-$HOME/.ai-devkit/config.yaml}"
    
    # Get primary repository URL from components array
    local url=$(yq -r ".components[] | select(.id == \"$component_id\") | .repositories[] | select(.primary == true) | .url // \"\"" "$config_file" 2>/dev/null | head -1)
    
    echo "$url"
}

# Function to get all repository URLs for a component
get_all_repo_urls() {
    local component_id="$1"
    local config_file="${2:-$HOME/.ai-devkit/config.yaml}"
    
    # Get all repository URLs from components array
    local urls=$(yq -r ".components[] | select(.id == \"$component_id\") | .repositories[].url // \"\"" "$config_file" 2>/dev/null)
    
    echo "$urls"
}

# Function to check if component has repository configuration
has_component_repos() {
    local component_id="$1"
    local config_file="${2:-$HOME/.ai-devkit/config.yaml}"
    
    local repos=$(read_component_repos "$component_id" "$config_file")
    
    if [[ -n "$repos" ]] && [[ "$repos" != "[]" ]] && [[ "$repos" != "null" ]]; then
        return 0  # true - has repos
    else
        return 1  # false - no repos
    fi
}