#!/bin/bash

# Component Configuration Generator
# This script generates repository configurations dynamically based on selected components
# and user's config.yaml settings. It replaces the hardcoded language-specific logic.

set -e

# Source the config reader library for consistent config access
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config-reader.sh"

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
            # For K3s, try to detect the host machine name or use the Nexus URL host
            local nexus_url=$(yq -r '.nexus.url // ""' "$CONFIG_FILE" 2>/dev/null)
            if [[ -n "$nexus_url" ]] && [[ "$nexus_url" != "null" ]]; then
                # Extract host from URL (e.g., http://pop-os:8081 -> pop-os)
                echo "$nexus_url" | sed -E 's|https?://([^:/]+).*|\1|'
            else
                # Fallback to gateway IP
                echo "host.k3s.internal"
            fi
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
    
    # Read repository configuration from config.yaml
    local repos=$(read_component_repos "$component_id" "$CONFIG_FILE")
    
    if [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]] || [[ -z "$repos" ]]; then
        echo "No repository configuration found for $component_id" >&2
        return 1
    fi
    
    # Get primary repository
    local primary_url=$(echo "$repos" | yq -r '.[] | select(.primary == true) | .url' 2>/dev/null | head -1)
    if [[ -z "$primary_url" ]] || [[ "$primary_url" == "null" ]]; then
        # Fallback to first repository if no primary designated
        primary_url=$(echo "$repos" | yq -r '.[0].url' 2>/dev/null)
    fi
    
    if [[ -z "$primary_url" ]] || [[ "$primary_url" == "null" ]]; then
        echo "No repository URL found for $component_id" >&2
        return 1
    fi
    
    # Translate URL for container access
    primary_url=$(translate_url "$primary_url")
    
    # Extract host for trusted-host
    local host=$(echo "$primary_url" | sed -E 's|https?://([^:/]+).*|\1|')
    
    # Generate pip.conf
    cat > "$config_file" << EOF
[global]
index-url = ${primary_url}/simple
trusted-host = $host
EOF
    
    # Add extra index URLs if present
    local extra_urls=$(echo "$repos" | yq -r '.[] | select(.primary != true) | .url' 2>/dev/null)
    if [[ -n "$extra_urls" ]] && [[ "$extra_urls" != "null" ]]; then
        echo "extra-index-url =" >> "$config_file"
        while IFS= read -r url; do
            url=$(translate_url "$url")
            echo "    ${url}/simple" >> "$config_file"
        done <<< "$extra_urls"
    fi
    
    echo "Generated pip.conf at $config_file" >&2
}

# Function to generate npm configuration
generate_npm_config() {
    local component_id="$1"
    local config_file="$2"
    
    echo "Generating npm configuration for $component_id..." >&2
    
    # Read repository configuration from config.yaml
    local repos=$(read_component_repos "$component_id" "$CONFIG_FILE")
    
    if [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]] || [[ -z "$repos" ]]; then
        echo "No repository configuration found for $component_id" >&2
        return 1
    fi
    
    # Get primary repository
    local primary_url=$(echo "$repos" | yq -r '.[] | select(.primary == true) | .url' 2>/dev/null | head -1)
    if [[ -z "$primary_url" ]] || [[ "$primary_url" == "null" ]]; then
        primary_url=$(echo "$repos" | yq -r '.[0].url' 2>/dev/null)
    fi
    
    if [[ -z "$primary_url" ]] || [[ "$primary_url" == "null" ]]; then
        echo "No repository URL found for $component_id" >&2
        return 1
    fi
    
    # Translate URL for container access
    primary_url=$(translate_url "$primary_url")
    
    # Generate npmrc
    echo "registry=${primary_url}/" > "$config_file"
    
    echo "Generated npmrc at $config_file" >&2
}

# Function to generate Go proxy configuration
generate_go_config() {
    local component_id="$1"
    local config_file="$2"
    
    echo "Generating Go proxy configuration for $component_id..." >&2
    
    # Read repository configuration from config.yaml
    local repos=$(read_component_repos "$component_id" "$CONFIG_FILE")
    
    if [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]] || [[ -z "$repos" ]]; then
        echo "No repository configuration found for $component_id" >&2
        return 1
    fi
    
    # Build proxy list from all repositories
    local proxy_list=""
    local urls=$(echo "$repos" | yq -r '.[].url' 2>/dev/null)
    while IFS= read -r url; do
        if [[ -n "$url" ]] && [[ "$url" != "null" ]]; then
            url=$(translate_url "$url")
            if [[ -z "$proxy_list" ]]; then
                proxy_list="$url"
            else
                proxy_list="${proxy_list},${url}"
            fi
        fi
    done <<< "$urls"
    
    # Generate go env file
    cat > "$config_file" << EOF
export GOPROXY="${proxy_list},direct"
export GOPRIVATE=""
export GONOSUMDB=""
EOF
    
    echo "Generated Go env at $config_file" >&2
}

# Function to generate Maven settings.xml
generate_maven_config() {
    local component_id="$1"
    local config_file="$2"
    
    echo "Generating Maven configuration for $component_id..." >&2
    
    # Read repository configuration from config.yaml
    local repos=$(read_component_repos "$component_id" "$CONFIG_FILE")
    
    if [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]] || [[ -z "$repos" ]]; then
        echo "No repository configuration found for $component_id" >&2
        return 1
    fi
    
    # Get primary repository
    local primary_url=$(echo "$repos" | yq -r '.[] | select(.primary == true) | .url' 2>/dev/null | head -1)
    if [[ -z "$primary_url" ]] || [[ "$primary_url" == "null" ]]; then
        primary_url=$(echo "$repos" | yq -r '.[0].url' 2>/dev/null)
    fi
    
    primary_url=$(translate_url "$primary_url")
    
    # Generate settings.xml
    cat > "$config_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              http://maven.apache.org/xsd/settings-1.0.0.xsd">
    <mirrors>
        <mirror>
            <id>nexus</id>
            <mirrorOf>*</mirrorOf>
            <url>${primary_url}</url>
        </mirror>
    </mirrors>
</settings>
EOF
    
    echo "Generated settings.xml at $config_file" >&2
}

# Function to generate Cargo configuration
generate_cargo_config() {
    local component_id="$1"
    local config_file="$2"
    
    echo "Generating Cargo configuration for $component_id..." >&2
    
    # Read repository configuration from config.yaml
    local repos=$(read_component_repos "$component_id" "$CONFIG_FILE")
    
    if [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]] || [[ -z "$repos" ]]; then
        echo "No repository configuration found for $component_id" >&2
        return 1
    fi
    
    # Get primary repository
    local primary_url=$(echo "$repos" | yq -r '.[] | select(.primary == true) | .url' 2>/dev/null | head -1)
    if [[ -z "$primary_url" ]] || [[ "$primary_url" == "null" ]]; then
        primary_url=$(echo "$repos" | yq -r '.[0].url' 2>/dev/null)
    fi
    
    primary_url=$(translate_url "$primary_url")
    
    # Generate config.toml
    cat > "$config_file" << EOF
[source.crates-io]
replace-with = "nexus"

[source.nexus]
registry = "sparse+${primary_url}/"
EOF
    
    echo "Generated cargo config at $config_file" >&2
}

# Function to generate RubyGems configuration
generate_gem_config() {
    local component_id="$1"
    local config_file="$2"
    
    echo "Generating RubyGems configuration for $component_id..." >&2
    
    # Read repository configuration from config.yaml
    local repos=$(read_component_repos "$component_id" "$CONFIG_FILE")
    
    if [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]] || [[ -z "$repos" ]]; then
        echo "No repository configuration found for $component_id" >&2
        return 1
    fi
    
    # Generate gemrc with all repositories as sources
    echo "---" > "$config_file"
    echo ":sources:" >> "$config_file"
    
    local urls=$(echo "$repos" | yq -r '.[].url' 2>/dev/null)
    while IFS= read -r url; do
        if [[ -n "$url" ]] && [[ "$url" != "null" ]]; then
            url=$(translate_url "$url")
            echo "  - ${url}" >> "$config_file"
        fi
    done <<< "$urls"
    
    echo "Generated gemrc at $config_file" >&2
}

# Function to generate SBT repositories configuration
generate_sbt_config() {
    local component_id="$1"
    local config_file="$2"
    
    echo "Generating SBT configuration for $component_id..." >&2
    
    # Read repository configuration from config.yaml
    local repos=$(read_component_repos "$component_id" "$CONFIG_FILE")
    
    if [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]] || [[ -z "$repos" ]]; then
        echo "No repository configuration found for $component_id" >&2
        return 1
    fi
    
    # Generate repositories file
    echo "[repositories]" > "$config_file"
    echo "local" >> "$config_file"
    
    local i=0
    local urls=$(echo "$repos" | yq -r '.[].url' 2>/dev/null)
    while IFS= read -r url; do
        if [[ -n "$url" ]] && [[ "$url" != "null" ]]; then
            url=$(translate_url "$url")
            if [[ $i -eq 0 ]]; then
                echo "maven-central: ${url}" >> "$config_file"
            else
                echo "repo-${i}: ${url}" >> "$config_file"
            fi
            ((i++))
        fi
    done <<< "$urls"
    
    echo "Generated SBT repositories at $config_file" >&2
}

# Function to generate Gradle properties
generate_gradle_config() {
    local component_id="$1"
    local config_file="$2"
    
    echo "Generating Gradle configuration for $component_id..." >&2
    
    # Read repository configuration from config.yaml
    local repos=$(read_component_repos "$component_id" "$CONFIG_FILE")
    
    if [[ "$repos" == "[]" ]] || [[ "$repos" == "null" ]] || [[ -z "$repos" ]]; then
        echo "No repository configuration found for $component_id" >&2
        return 1
    fi
    
    # Get primary repository
    local primary_url=$(echo "$repos" | yq -r '.[] | select(.primary == true) | .url' 2>/dev/null | head -1)
    if [[ -z "$primary_url" ]] || [[ "$primary_url" == "null" ]]; then
        primary_url=$(echo "$repos" | yq -r '.[0].url' 2>/dev/null)
    fi
    
    primary_url=$(translate_url "$primary_url")
    
    # Generate gradle.properties
    echo "systemProp.nexus.url=${primary_url}" > "$config_file"
    
    echo "Generated gradle.properties at $config_file" >&2
}

# Main function to generate configuration for a component
generate_component_config() {
    local component_yaml="$1"
    local output_dir="${2:-$TEMP_DIR}"
    
    if [[ ! -f "$component_yaml" ]]; then
        echo "Component YAML file not found: $component_yaml" >&2
        return 1
    fi
    
    # Extract component metadata
    local component_id=$(yq -r '.id' "$component_yaml" 2>/dev/null)
    local format=$(yq -r '.installation.repos.format // ""' "$component_yaml" 2>/dev/null)
    local config_file_name=$(yq -r '.installation.repos.config_file // ""' "$component_yaml" 2>/dev/null)
    
    if [[ -z "$component_id" ]] || [[ "$component_id" == "null" ]]; then
        echo "No component ID found in $component_yaml" >&2
        return 1
    fi
    
    if [[ -z "$format" ]] || [[ "$format" == "null" ]]; then
        echo "Component $component_id does not have repository configuration" >&2
        return 0
    fi
    
    # Check if component has repository configuration in config.yaml
    if ! has_component_repos "$component_id" "$CONFIG_FILE"; then
        echo "No repository configuration for $component_id in config.yaml" >&2
        return 0
    fi
    
    # Generate configuration based on format
    local config_path=""
    case "$format" in
        "pypi")
            config_path="$output_dir/pip.conf"
            generate_pip_config "$component_id" "$config_path"
            ;;
        "npm")
            config_path="$output_dir/npmrc"
            generate_npm_config "$component_id" "$config_path"
            ;;
        "go")
            config_path="$output_dir/go-env.sh"
            generate_go_config "$component_id" "$config_path"
            ;;
        "maven2")
            config_path="$output_dir/settings.xml"
            generate_maven_config "$component_id" "$config_path"
            ;;
        "cargo")
            config_path="$output_dir/cargo-config.toml"
            generate_cargo_config "$component_id" "$config_path"
            ;;
        "rubygems")
            config_path="$output_dir/gemrc"
            generate_gem_config "$component_id" "$config_path"
            ;;
        "sbt")
            config_path="$output_dir/repositories"
            generate_sbt_config "$component_id" "$config_path"
            ;;
        "gradle")
            config_path="$output_dir/gradle.properties"
            generate_gradle_config "$component_id" "$config_path"
            ;;
        *)
            echo "Unknown repository format: $format for component $component_id" >&2
            return 1
            ;;
    esac
    
    # Output the generated config path for the caller
    if [[ -f "$config_path" ]]; then
        echo "$config_path"
    fi
}

# Function to generate all configurations for selected components
generate_all_configs() {
    local components=("$@")
    local configs_generated=()
    
    for component_yaml in "${components[@]}"; do
        echo "Processing component: $component_yaml" >&2
        local config_path=$(generate_component_config "$component_yaml")
        if [[ -n "$config_path" ]]; then
            configs_generated+=("$config_path")
        fi
    done
    
    # Return list of generated configs
    printf '%s\n' "${configs_generated[@]}"
}

# Cleanup function
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Export functions for use by other scripts
export -f get_container_host
export -f translate_url
export -f generate_component_config
export -f generate_all_configs
export -f cleanup