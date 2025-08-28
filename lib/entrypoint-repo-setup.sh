#!/bin/bash
# Repository Configuration for Entrypoint
# This script handles runtime repository configuration without language-specific logic

# Function to setup component repositories at runtime
setup_component_repos() {
    echo "Repository configuration is now handled at build time."
    echo "Configuration files are mounted directly into the container."
    # This function is kept for backward compatibility but does nothing
    return 0
}

# Check for mounted configuration files and report status
check_mounted_configs() {
    echo "Checking for mounted repository configurations..."
    
    # List of potential config files (only those actually mounted will exist)
    local configs=(
        "/home/devuser/.config/pip/pip.conf"
        "/home/devuser/.npmrc"
        "/home/devuser/.cargo/config.toml"
        "/home/devuser/.m2/settings.xml"
        "/home/devuser/.sbt/repositories"
        "/home/devuser/.gemrc"
        "/home/devuser/.gradle/gradle.properties"
        "/home/devuser/.condarc"
    )
    
    local found_configs=0
    for config in "${configs[@]}"; do
        if [[ -f "$config" ]]; then
            echo "✓ Found configuration: $config"
            ((found_configs++))
        fi
    done
    
    if [[ $found_configs -eq 0 ]]; then
        echo "No repository configurations mounted. Using default repositories."
    else
        echo "Found $found_configs repository configuration(s)."
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_mounted_configs
fi