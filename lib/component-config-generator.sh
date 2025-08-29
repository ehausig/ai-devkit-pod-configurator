#!/bin/bash

# Component Configuration Generator
# Completely rewritten for new repository configuration system

set -e

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config-reader.sh"
source "$SCRIPT_DIR/repository-loader.sh"
source "$SCRIPT_DIR/credential-manager.sh"

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration paths
CONFIG_FILE="${CONFIG_FILE:-$HOME/.ai-devkit/config.yaml}"
TEMP_DIR="${TEMP_DIR:-/tmp/ai-devkit-configs-$$}"

# Create temp directory for configs
mkdir -p "$TEMP_DIR"

# Function to get host address based on container runtime
get_container_host() {
    local runtime=$(yq -r '.container.runtime // "unknown"' "$CONFIG_FILE" 2>/dev/null)
    local configured_host=""
    
    # First check if there's a configured container_host
    configured_host=$(yq -r '.container.container_host // ""' "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$configured_host" ]] && [[ "$configured_host" != "null" ]]; then
        echo "$configured_host"
        return
    fi
    
    # Otherwise use runtime-specific defaults
    case "$runtime" in
        "colima")
            echo "host.lima.internal"
            ;;
        "docker-desktop")
            echo "host.docker.internal"
            ;;
        "minikube")
            echo "host.minikube.internal"
            ;;
        "k3s")
            # For K3s, use the actual hostname
            local host_name=$(hostname 2>/dev/null || echo "host.k3s.internal")
            if [[ "$host_name" == "localhost" ]]; then
                host_name="host.k3s.internal"
            fi
            echo "$host_name"
            ;;
        *)
            echo "host.docker.internal"
            ;;
    esac
}

# Function to translate URLs from host to container perspective
translate_url() {
    local url="$1"
    local container_host=$(get_container_host)
    
    # Replace localhost with container-accessible host
    echo "$url" | sed "s/localhost/$container_host/g"
}

# Function to generate pip configuration
generate_pip_config() {
    local component_id="$1"
    local config_file="$2"
    
    echo "Generating pip configuration for $component_id..." >&2
    
    # Resolve repositories with merging logic
    local repos=$(resolve_repositories "$component_id")
    
    if [[ -z "$repos" ]] || [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]]; then
        echo "No repositories configured for $component_id" >&2
        return 1
    fi
    
    # Parse repositories
    local num_repos=$(echo "$repos" | yq -r '. | length')
    
    if [[ $num_repos -eq 0 ]]; then
        echo "No repositories to configure for $component_id" >&2
        return 1
    fi
    
    # Start building pip.conf
    echo "[global]" > "$config_file"
    
    # First repository becomes index-url
    local first_repo=$(echo "$repos" | yq -r '.[0]')
    local url=$(echo "$first_repo" | yq -r '.url // ""')
    local auth=$(echo "$first_repo" | yq -r '.auth // ""')
    
    # Translate URL for container access
    url=$(translate_url "$url")
    
    # Add authentication if needed
    if [[ -n "$auth" ]] && [[ "$auth" != "null" ]]; then
        if has_basic_auth "$auth"; then
            url=$(add_basic_auth_to_url "$url" "$auth")
        fi
    fi
    
    echo "index-url = $url" >> "$config_file"
    
    # Extract host for trusted-host
    local host=$(echo "$url" | sed -E 's|https?://([^:/]+).*|\1|' | sed 's/@.*//')
    if [[ -n "$host" ]] && [[ "$url" == http://* ]]; then
        echo "trusted-host = $host" >> "$config_file"
    fi
    
    # Additional repositories become extra-index-url
    if [[ $num_repos -gt 1 ]]; then
        echo "extra-index-url =" >> "$config_file"
        
        for i in $(seq 1 $((num_repos - 1))); do
            local repo=$(echo "$repos" | yq -r ".[$i]")
            local extra_url=$(echo "$repo" | yq -r '.url // ""')
            local extra_auth=$(echo "$repo" | yq -r '.auth // ""')
            
            # Translate URL
            extra_url=$(translate_url "$extra_url")
            
            # Add authentication if needed
            if [[ -n "$extra_auth" ]] && [[ "$extra_auth" != "null" ]]; then
                if has_basic_auth "$extra_auth"; then
                    extra_url=$(add_basic_auth_to_url "$extra_url" "$extra_auth")
                fi
            fi
            
            echo "    $extra_url" >> "$config_file"
        done
    fi
    
    echo "Generated pip configuration with $num_repos repositories" >&2
    return 0
}

# Function to generate npm configuration
generate_npm_config() {
    local component_id="$1"
    local config_file="$2"
    
    echo "Generating npm configuration for $component_id..." >&2
    
    # Resolve repositories with merging logic
    local repos=$(resolve_repositories "$component_id")
    
    if [[ -z "$repos" ]] || [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]]; then
        echo "No repositories configured for $component_id" >&2
        return 1
    fi
    
    # Parse repositories
    local num_repos=$(echo "$repos" | yq -r '. | length')
    
    if [[ $num_repos -eq 0 ]]; then
        echo "No repositories to configure for $component_id" >&2
        return 1
    fi
    
    # First repository becomes the main registry
    local first_repo=$(echo "$repos" | yq -r '.[0]')
    local url=$(echo "$first_repo" | yq -r '.url // ""')
    local auth=$(echo "$first_repo" | yq -r '.auth // ""')
    
    # Translate URL for container access
    url=$(translate_url "$url")
    
    echo "registry=$url" > "$config_file"
    
    # Add authentication if needed
    if [[ -n "$auth" ]] && [[ "$auth" != "null" ]]; then
        local username=$(get_credential_username "$auth")
        local password=$(get_credential_password "$auth")
        
        if [[ -n "$username" ]] && [[ -n "$password" ]]; then
            # Extract host from URL for auth
            local host=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|')
            echo "//$host/:_authToken=$(echo -n "${username}:${password}" | base64)" >> "$config_file"
        fi
    fi
    
    echo "Generated npm configuration with $num_repos repositories" >&2
    return 0
}

# Function to generate Go environment variables
generate_go_env() {
    local component_id="$1"
    local env_file="$2"
    
    echo "Generating Go environment configuration for $component_id..." >&2
    
    # Resolve repositories with merging logic
    local repos=$(resolve_repositories "$component_id")
    
    if [[ -z "$repos" ]] || [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]]; then
        echo "No repositories configured for $component_id" >&2
        return 1
    fi
    
    # Get first repository URL for GOPROXY
    local first_repo=$(echo "$repos" | yq -r '.[0]')
    local url=$(echo "$first_repo" | yq -r '.url // ""')
    local auth=$(echo "$first_repo" | yq -r '.auth // ""')
    
    # Translate URL for container access
    url=$(translate_url "$url")
    
    # Add authentication if needed
    if [[ -n "$auth" ]] && [[ "$auth" != "null" ]]; then
        if has_basic_auth "$auth"; then
            url=$(add_basic_auth_to_url "$url" "$auth")
        fi
    fi
    
    # Write environment variables
    echo "export GOPROXY=\"${url},direct\"" > "$env_file"
    echo "export GOSUMDB=\"sum.golang.org\"" >> "$env_file"
    echo "export GO111MODULE=on" >> "$env_file"
    
    echo "Generated Go environment configuration" >&2
    return 0
}

# Function to generate Maven settings.xml
generate_maven_settings() {
    local component_id="$1"
    local config_file="$2"
    
    echo "Generating Maven settings for $component_id..." >&2
    
    # Resolve repositories with merging logic
    local repos=$(resolve_repositories "$component_id")
    
    if [[ -z "$repos" ]] || [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]]; then
        echo "No repositories configured for $component_id" >&2
        return 1
    fi
    
    # Start building settings.xml
    cat > "$config_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              http://maven.apache.org/xsd/settings-1.0.0.xsd">
    <mirrors>
EOF
    
    # Process each repository
    local num_repos=$(echo "$repos" | yq -r '. | length')
    
    for i in $(seq 0 $((num_repos - 1))); do
        local repo=$(echo "$repos" | yq -r ".[$i]")
        local name=$(echo "$repo" | yq -r '.name // "repo'$i'"')
        local url=$(echo "$repo" | yq -r '.url // ""')
        local auth=$(echo "$repo" | yq -r '.auth // ""')
        
        # Translate URL
        url=$(translate_url "$url")
        
        # Add as mirror
        cat >> "$config_file" << EOF
        <mirror>
            <id>$name</id>
            <mirrorOf>*</mirrorOf>
            <url>$url</url>
        </mirror>
EOF
    done
    
    echo "    </mirrors>" >> "$config_file"
    
    # Add authentication servers if needed
    local has_auth=false
    for i in $(seq 0 $((num_repos - 1))); do
        local repo=$(echo "$repos" | yq -r ".[$i]")
        local auth=$(echo "$repo" | yq -r '.auth // ""')
        
        if [[ -n "$auth" ]] && [[ "$auth" != "null" ]]; then
            if [[ "$has_auth" == "false" ]]; then
                echo "    <servers>" >> "$config_file"
                has_auth=true
            fi
            
            local name=$(echo "$repo" | yq -r '.name // "repo'$i'"')
            local username=$(get_credential_username "$auth")
            local password=$(get_credential_password "$auth")
            
            if [[ -n "$username" ]] && [[ -n "$password" ]]; then
                cat >> "$config_file" << EOF
        <server>
            <id>$name</id>
            <username>$username</username>
            <password>$password</password>
        </server>
EOF
            fi
        fi
    done
    
    if [[ "$has_auth" == "true" ]]; then
        echo "    </servers>" >> "$config_file"
    fi
    
    echo "</settings>" >> "$config_file"
    
    echo "Generated Maven settings with $num_repos repositories" >&2
    return 0
}

# Function to generate Cargo configuration
generate_cargo_config() {
    local component_id="$1"
    local config_file="$2"
    
    echo "Generating Cargo configuration for $component_id..." >&2
    
    # Resolve repositories with merging logic
    local repos=$(resolve_repositories "$component_id")
    
    if [[ -z "$repos" ]] || [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]]; then
        echo "No repositories configured for $component_id" >&2
        return 1
    fi
    
    # Get first repository
    local first_repo=$(echo "$repos" | yq -r '.[0]')
    local url=$(echo "$first_repo" | yq -r '.url // ""')
    local auth=$(echo "$first_repo" | yq -r '.auth // ""')
    
    # Translate URL
    url=$(translate_url "$url")
    
    # Generate Cargo config
    echo "[source.crates-io]" > "$config_file"
    echo "replace-with = \"custom\"" >> "$config_file"
    echo "" >> "$config_file"
    echo "[source.custom]" >> "$config_file"
    echo "registry = \"$url\"" >> "$config_file"
    
    # Add authentication if needed
    if [[ -n "$auth" ]] && [[ "$auth" != "null" ]]; then
        local token=$(get_credential_token "$auth")
        if [[ -n "$token" ]]; then
            echo "" >> "$config_file"
            echo "[registries.custom]" >> "$config_file"
            echo "token = \"$token\"" >> "$config_file"
        fi
    fi
    
    echo "Generated Cargo configuration" >&2
    return 0
}

# Main function to generate component configuration
generate_component_config() {
    local component_yaml="$1"
    local output_dir="${2:-$TEMP_DIR}"
    
    if [[ ! -f "$component_yaml" ]]; then
        echo "Component YAML not found: $component_yaml" >&2
        return 1
    fi
    
    # Extract component information
    local component_id=$(yq -r '.id // ""' "$component_yaml" 2>/dev/null)
    local format=$(yq -r '.installation.repos.format // ""' "$component_yaml" 2>/dev/null)
    
    if [[ -z "$component_id" ]] || [[ -z "$format" ]] || [[ "$format" == "null" ]]; then
        echo "Component $component_id does not have repository configuration" >&2
        return 0
    fi
    
    echo "Processing component $component_id with format $format" >&2
    
    # Generate configuration based on format
    case "$format" in
        "pypi")
            generate_pip_config "$component_id" "$output_dir/pip.conf"
            ;;
        "npm")
            generate_npm_config "$component_id" "$output_dir/npmrc"
            ;;
        "go")
            generate_go_env "$component_id" "$output_dir/go-env.sh"
            ;;
        "maven2")
            generate_maven_settings "$component_id" "$output_dir/settings.xml"
            ;;
        "cargo")
            generate_cargo_config "$component_id" "$output_dir/cargo-config.toml"
            ;;
        *)
            echo "Unknown repository format: $format" >&2
            return 1
            ;;
    esac
    
    return 0
}

# Main function exported for use by other scripts
export -f generate_component_config