#!/bin/bash

# Repository Loader - Load and merge repository configurations
# Part of the repository configuration refactoring

# Only set strict mode if not being sourced interactively
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -e
fi

# Check for required tools (warning only when sourced)
if ! command -v yq >/dev/null 2>&1 && ! command -v /usr/local/bin/yq >/dev/null 2>&1; then
    echo "Warning: yq is not found in PATH. Some functions may not work." >&2
    # Don't exit if being sourced
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        exit 1
    fi
fi

# Source credential manager
# Get the directory of this script
if [[ -n "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Fallback for other shells or when sourced
    SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
    # If still not found, try relative to current working directory
    if [[ ! -f "$SCRIPT_DIR/credential-manager.sh" ]]; then
        SCRIPT_DIR="$(pwd)/lib"
    fi
fi

if [[ -f "$SCRIPT_DIR/credential-manager.sh" ]]; then
    source "$SCRIPT_DIR/credential-manager.sh"
else
    echo "Warning: credential-manager.sh not found at $SCRIPT_DIR" >&2
fi

# Configuration file location
CONFIG_FILE="${CONFIG_FILE:-$HOME/.ai-devkit/config.yaml}"

# Function to find component directory
find_component_dir() {
    local component_id="$1"
    local base_dir="${2:-components}"
    
    # Search for component YAML file
    local component_file=$(find "$base_dir" -name "*.yaml" -exec grep -l "^id: $component_id$" {} \; 2>/dev/null | head -1)
    
    if [[ -z "$component_file" ]]; then
        return 1
    fi
    
    # Get directory name (remove .yaml extension)
    local component_dir="${component_file%.yaml}"
    
    if [[ -d "$component_dir" ]]; then
        echo "$component_dir"
        return 0
    fi
    
    return 1
}

# Function to load default repositories from config
load_default_repositories() {
    local config_file="${1:-config/repositories.yaml}"
    
    if [[ -f "$config_file" ]]; then
        cat "$config_file"
    else
        echo "{}"
    fi
}

# Function to load override repositories
load_override_repositories() {
    local override_file="${1:-$HOME/.ai-devkit/repositories.yaml}"
    
    if [[ -f "$override_file" ]]; then
        cat "$override_file"
    else
        echo "{}"
    fi
}

# Function to load default repositories for a component
load_default_repos() {
    local component_id="$1"
    local component_dir="$2"
    
    if [[ -z "$component_dir" ]]; then
        component_dir=$(find_component_dir "$component_id")
    fi
    
    local defaults_file="$component_dir/ai-devkit/repos.yaml"
    
    if [[ ! -f "$defaults_file" ]]; then
        # No defaults for this component
        echo "[]"
        return 0
    fi
    
    # Load and return repositories as JSON
    # Check which yq version we have
    local yq_path=$(command -v yq 2>/dev/null)
    if [[ -n "$yq_path" ]] && head -1 "$yq_path" 2>/dev/null | grep -q "python"; then
        # kislyuk/yq - uses jq syntax
        cat "$defaults_file" | yq -r '.repositories // []' 2>/dev/null
    else
        # mikefarah/yq - uses eval syntax
        yq eval '.repositories // []' "$defaults_file" 2>/dev/null
    fi
}

# Function to load environment variables for a component
load_env_vars() {
    local component_id="$1"
    local component_dir="$2"
    
    if [[ -z "$component_dir" ]]; then
        component_dir=$(find_component_dir "$component_id")
    fi
    
    local env_file="$component_dir/ai-devkit/env_vars.yaml"
    
    if [[ ! -f "$env_file" ]]; then
        # No env vars for this component
        echo "[]"
        return 0
    fi
    
    # Load and return env vars as JSON
    yq -r '.env_vars // []' "$env_file" 2>/dev/null
}

# Function to get user repository configuration for a component
get_user_repos() {
    local component_id="$1"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "[]"
        return 0
    fi
    
    # Get repositories for this component from user config
    yq -r ".components[] | select(.id == \"$component_id\") | .repositories // []" "$CONFIG_FILE" 2>/dev/null
}

# Function to check if user wants to include default repos
get_include_defaults() {
    local component_id="$1"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "true"  # Default behavior
        return 0
    fi
    
    # Check include_default_repos flag (default: true)
    # Note: yq returns "true" or "false" as strings for boolean values
    local include=$(yq -r ".components[] | select(.id == \"$component_id\") | .include_default_repos" "$CONFIG_FILE" 2>/dev/null)
    
    if [[ -z "$include" ]] || [[ "$include" == "null" ]]; then
        echo "true"  # Default if not specified
    else
        echo "$include"  # Will be "true" or "false" as string
    fi
}

# Function to merge repositories (user repos take priority)
merge_repositories() {
    local component_id="$1"
    local default_repos="$2"
    local user_repos="$3"
    local include_defaults="$4"
    
    # Use temporary files for processing
    local temp_defaults="/tmp/defaults_$$"
    local temp_user="/tmp/user_$$"
    local temp_merged="/tmp/merged_$$"
    
    echo "$default_repos" > "$temp_defaults"
    echo "$user_repos" > "$temp_user"
    
    # Start with empty array
    echo "[]" > "$temp_merged"
    
    # Add user repositories first (higher priority)
    if [[ -n "$user_repos" ]] && [[ "$user_repos" != "[]" ]] && [[ "$user_repos" != "null" ]]; then
        echo "$user_repos" > "$temp_merged"
    fi
    
    # Add default repositories if requested
    if [[ "$include_defaults" == "true" ]]; then
        # Get list of user repo names to check for conflicts
        local user_repo_names=$(echo "$user_repos" | yq -r '.[].name // ""' 2>/dev/null)
        
        # Process each default repo
        echo "$default_repos" | yq -r '.[] | @json' 2>/dev/null | while IFS= read -r repo_json; do
            if [[ -n "$repo_json" ]] && [[ "$repo_json" != "null" ]]; then
                local repo_name=$(echo "$repo_json" | yq -r '.name // ""')
                
                # Check if this name conflicts with user repos
                if echo "$user_repo_names" | grep -q "^${repo_name}$"; then
                    echo "WARNING: Skipping default repo '$repo_name' - overridden by user config" >&2
                else
                    # Add to merged list
                    local current=$(cat "$temp_merged")
                    echo "$current" | yq ". + [$repo_json]" > "$temp_merged.new"
                    mv "$temp_merged.new" "$temp_merged"
                fi
            fi
        done
    fi
    
    # Output final merged list
    cat "$temp_merged"
    
    # Cleanup
    rm -f "$temp_defaults" "$temp_user" "$temp_merged"
}

# Function to resolve credentials for repositories
resolve_repository_credentials() {
    local repos_json="$1"
    
    if [[ -z "$repos_json" ]] || [[ "$repos_json" == "[]" ]]; then
        echo "[]"
        return 0
    fi
    
    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$repos_json"
        return 0
    fi
    
    # Process each repository and resolve auth references
    local temp_file="/tmp/repos_with_creds_$$"
    echo "$repos_json" > "$temp_file"
    
    # Get repository count
    local repo_count=$(echo "$repos_json" | yq 'length' 2>/dev/null || echo "0")
    
    # Process each repository
    local result="[]"
    for (( i=0; i<repo_count; i++ )); do
        local repo=$(echo "$repos_json" | yq ".[$i]" 2>/dev/null)
        local auth_ref=$(echo "$repo" | yq '.auth // ""' 2>/dev/null)
        
        if [[ -n "$auth_ref" ]] && [[ "$auth_ref" != "null" ]] && [[ "$auth_ref" != '""' ]]; then
            # Look up credentials
            local cred=$(yq ".credentials[] | select(.id == \"$auth_ref\")" "$CONFIG_FILE" 2>/dev/null)
            
            if [[ -n "$cred" ]] && [[ "$cred" != "null" ]]; then
                local username=$(echo "$cred" | yq '.username // ""' 2>/dev/null)
                local password=$(echo "$cred" | yq '.password // ""' 2>/dev/null)
                
                # Add credentials to repository object
                repo=$(echo "$repo" | yq ". + {\"username\": \"$username\", \"password\": \"$password\"}" 2>/dev/null)
            fi
        fi
        
        # Add to result
        result=$(echo "$result" | yq ". + [$repo]" 2>/dev/null)
    done
    
    rm -f "$temp_file"
    echo "$result"
}

# Function to resolve all repositories for a component
resolve_repositories() {
    local component_id="$1"
    local component_dir="${2:-}"
    
    # Load defaults
    local default_repos=$(load_default_repos "$component_id" "$component_dir")
    
    # Get user configuration
    local user_repos=$(get_user_repos "$component_id")
    local include_defaults=$(get_include_defaults "$component_id")
    
    # Log what we're doing
    if [[ -n "$user_repos" ]] && [[ "$user_repos" != "[]" ]]; then
        echo "Loading user repositories for $component_id" >&2
    fi
    
    if [[ "$include_defaults" == "true" ]] && [[ -n "$default_repos" ]] && [[ "$default_repos" != "[]" ]]; then
        echo "Loading default repositories for $component_id" >&2
    fi
    
    # Merge repositories
    local merged_repos=$(merge_repositories "$component_id" "$default_repos" "$user_repos" "$include_defaults")
    
    # Resolve credentials for merged repositories
    resolve_repository_credentials "$merged_repos"
}